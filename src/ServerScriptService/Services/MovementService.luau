--!strict
--[[
	MovementService.luau

	Server validation for slide, double jump, and dash (§C5).

	The client owns the *feel*: it starts the motion on the same frame the key
	is pressed, because a dash that waits for a round trip is not a dash. The
	server owns the *truth*: cooldowns, air-jump counts, and a hard displacement
	ceiling. A client that fabricates ability spam gets denials, and the
	authoritative speed clamp means a denied ability still cannot move them.

	Both sides read Config/Movement, so prediction and validation can never
	disagree about a tuning value.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Network.Events)
local MovementConfig = require(Shared.Config.Movement)
local RateLimits = require(Shared.Network.RateLimits)
local Schemas = require(Shared.Network.Schemas)

local MovementService = {}

type AbilityState = {
	lastSlideAt: number,
	lastDashAt: number,
	lastDoubleJumpAt: number,
	lastWallRunAt: number,
	lastWallJumpAt: number,
	airJumpsUsed: number,
	wallChain: number,
	lastGroundedAt: number,
}

local function newState(): AbilityState
	return {
		lastSlideAt = 0,
		lastDashAt = 0,
		lastDoubleJumpAt = 0,
		lastWallRunAt = 0,
		lastWallJumpAt = 0,
		airJumpsUsed = 0,
		wallChain = 0,
		lastGroundedAt = os.clock(),
	}
end

function MovementService:Init(context)
	self.states = {} :: { [Player]: AbilityState }
	self.combat = context.services.CombatService
end

function MovementService:Start()
	self.requestRemote = Events.get("C2S_MovementAbility")
	self.responseRemote = Events.get("S2C_MovementResponse")

	self.requestRemote.OnServerEvent:Connect(function(player, payload)
		self:_handleRequest(player, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		self.states[player] = newState()
		player.CharacterAdded:Connect(function(character)
			self.states[player] = newState()
			self:_bindCharacter(player, character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.states[player] = nil
	end)
end

function MovementService:_bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = MovementConfig.BaseWalkSpeed
	humanoid.JumpPower = MovementConfig.JumpPower
	humanoid.UseJumpPower = true

	-- Landing resets the air-jump budget. Tracked server-side so a client
	-- cannot simply claim it landed.
	humanoid.StateChanged:Connect(function(_, new)
		local state = self.states[player]
		if not state then
			return
		end
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			state.airJumpsUsed = 0
			-- Touching the ground clears the wall chain. This is the server's
			-- copy of the rule that stops a player alternating walls to climb
			-- out of an arena; the client enforces the same limit for feel.
			state.wallChain = 0
			state.lastGroundedAt = os.clock()
		end
	end)
end

function MovementService:_deny(player: Player, ability: string, reason: string)
	self.responseRemote:FireClient(player, ability, false, Schemas.RejectionCodes.Cooldown)
	-- Denials are logged but never punished on their own: a player on a spiky
	-- connection will legitimately produce some (§15.3).
	if RateLimits.rejectionCount(player.UserId, "MovementAbility") > 40 then
		warn(`[MovementService] sustained denials for {player.Name}: {reason}`)
	end
end

--[[
	Casts left and right from the character to confirm a near-vertical surface
	is genuinely within reach. Mirrors MovementController:_detectWall, with a
	slightly wider tolerance for client/server position skew.
]]
function MovementService:_hasAdjacentWall(character: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local distance = MovementConfig.WallRun.DetectionDistance * 1.6
	for _, side in { -1, 1 } do
		local hit = Workspace:Raycast(root.Position, root.CFrame.RightVector * side * distance, params)
		if hit and math.abs(hit.Normal.Y) < 0.45 then
			return true
		end
	end

	return false
end

function MovementService:_handleRequest(player: Player, payload: any)
	if not RateLimits.consume(player.UserId, "MovementAbility") then
		return self:_deny(player, "Unknown", "rate limited")
	end

	local ok, cleaned = Schemas.validateMovementRequest(payload)
	if not ok then
		return self:_deny(player, "Unknown", `malformed: {cleaned}`)
	end

	local state = self.states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or not character or not humanoid or humanoid.Health <= 0 then
		return self:_deny(player, cleaned.ability, "no live character")
	end

	local now = os.clock()
	local grace = MovementConfig.Validation.CooldownGrace

	if cleaned.ability == "Dash" then
		if now - state.lastDashAt < MovementConfig.Dash.Cooldown - grace then
			return self:_deny(player, "Dash", "dash on cooldown")
		end
		state.lastDashAt = now

		-- The dodge i-frame window is granted by the server, so it is real
		-- rather than a client-side claim. This is also the OnDodge trigger
		-- point the mod system hooks later (§8.6).
		self.combat:SetInvulnerable(character, MovementConfig.Dash.InvulnerabilityWindow)
		self.responseRemote:FireClient(player, "Dash", true)
		return
	end

	if cleaned.ability == "Slide" then
		if now - state.lastSlideAt < MovementConfig.Slide.Cooldown - grace then
			return self:_deny(player, "Slide", "slide on cooldown")
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return self:_deny(player, "Slide", "no root part")
		end

		-- Slide requires genuine momentum, otherwise it is a free speed boost
		-- from a standing start.
		local horizontalSpeed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		if horizontalSpeed < MovementConfig.Slide.MinimumEntrySpeed * 0.7 then
			return self:_deny(player, "Slide", "insufficient entry speed")
		end

		state.lastSlideAt = now
		self.responseRemote:FireClient(player, "Slide", true)
		return
	end

	if cleaned.ability == "WallRun" then
		if now - state.lastWallRunAt < MovementConfig.WallRun.Cooldown - grace then
			return self:_deny(player, "WallRun", "wall run on cooldown")
		end

		-- The hard ceiling on wall chaining. The client stops at the same
		-- number for feel; this is the copy that actually binds.
		if state.wallChain >= MovementConfig.Validation.MaxWallChain then
			return self:_deny(player, "WallRun", "wall chain limit reached")
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return self:_deny(player, "WallRun", "no root part")
		end

		-- Re-confirm a wall actually exists next to the player. Without this
		-- the ability is a free midair speed boost anywhere on the map.
		if not self:_hasAdjacentWall(character, root) then
			return self:_deny(player, "WallRun", "no wall adjacent to player")
		end

		state.wallChain += 1
		state.lastWallRunAt = now
		self.responseRemote:FireClient(player, "WallRun", true)
		return
	end

	if cleaned.ability == "WallJump" then
		if now - state.lastWallJumpAt < MovementConfig.WallRun.WallJump.Cooldown - grace then
			return self:_deny(player, "WallJump", "wall jump on cooldown")
		end

		-- The sanctioned wallhop: a wall jump refunds the air jump. The refund
		-- is granted here, not claimed by the client, so it stays one per wall
		-- rather than one per seam.
		if MovementConfig.WallRun.WallJump.RefundsAirJump then
			state.airJumpsUsed = 0
		end

		state.lastWallJumpAt = now
		self.responseRemote:FireClient(player, "WallJump", true)
		return
	end

	if cleaned.ability == "DoubleJump" then
		if now - state.lastDoubleJumpAt < MovementConfig.DoubleJump.Cooldown - grace then
			return self:_deny(player, "DoubleJump", "double jump on cooldown")
		end
		if state.airJumpsUsed >= MovementConfig.DoubleJump.MaxAirJumps then
			return self:_deny(player, "DoubleJump", "air jumps exhausted")
		end

		state.airJumpsUsed += 1
		state.lastDoubleJumpAt = now
		self.responseRemote:FireClient(player, "DoubleJump", true)
		return
	end
end

return MovementService
