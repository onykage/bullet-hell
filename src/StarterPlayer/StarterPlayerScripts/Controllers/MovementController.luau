--!strict
--[[
	MovementController.luau

	Slide, double jump, dash, and wall run — predicted locally, validated by
	the server.

	Design notes:

	  Slide  — entered from a sprint by pressing crouch. Carries momentum that
	           bleeds off against friction, accelerates downhill, and ends when
	           it drops below a minimum speed. It is a commitment, not a toggle.

	  Double jump — one air jump, with the fall velocity cancelled first so a
	           late press still saves you. Coyote time means walking off a ledge
	           does not silently eat your ground jump.

	  Dash   — a short burst with server-granted invulnerability frames. This is
	           the dodge the bullet-hell layer is balanced around (§5.2).

	  Wall run — the sanctioned form of Roblox's "wallhop" glitch. Walls really
	           do refund air options, but bounded: see Config/Movement and
	           docs/decisions/0003-wall-run.md.

	PHYSICS RULES, learned the hard way (see the comments in Config/Movement):

	  1. Constraint MaxForce is a large finite number, never math.huge.
	  2. A velocity constraint always preserves the character's own Y velocity
	     unless the ability explicitly means to cancel gravity. Pinning Y to
	     zero makes the character hover and never re-contact the ground.
	  3. Grounding is decided by a raycast, never by Humanoid:GetState(). The
	     Humanoid flips to Freefall for a frame whenever a constraint takes
	     over, and a state-based check cancels the very ability that caused it.

	Everything reads Config/Movement, the same module the server validates
	against, so a tuning change can never desync feel from authority.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Network.Events)
local MovementConfig = require(Shared.Config.Movement)

local GROUND_RAY_LENGTH = 4.0

local MovementController = {}

function MovementController:Init(context)
	self.player = context.player
	self.input = context.controllers.InputController
	self.camera = context.controllers.CameraController
	self.hud = context.controllers.HUDController

	self.sliding = false
	self.slideVelocity = Vector3.zero
	self.slideStartedAt = 0
	self.lastSlideAt = -math.huge
	self.lastDashAt = -math.huge
	self.dashUntil = 0
	self.airJumpsUsed = 0
	self.lastGroundedAt = 0

	self.wallRunning = false
	self.wallStartedAt = 0
	self.lastWallAt = -math.huge
	self.lastWallJumpAt = -math.huge
	self.wallNormal = Vector3.zero
	self.wallSide = 0 -- -1 left, 1 right
	self.wallChain = 0
	self.lastWallInstance = nil :: BasePart?

	self.character = nil :: Model?
	self.humanoid = nil :: Humanoid?
	self.root = nil :: BasePart?
	self.slideForce = nil :: LinearVelocity?
	self.wallForce = nil :: LinearVelocity?
end

function MovementController:Start()
	self.requestRemote = Events.get("C2S_MovementAbility")
	self.responseRemote = Events.get("S2C_MovementResponse")

	self.responseRemote.OnClientEvent:Connect(function(ability: string, approved: boolean)
		-- A denial means the client and server disagreed. Rather than snapping
		-- the player (which feels awful and is usually the server being
		-- cautious), the prediction is simply ended early.
		if approved then
			return
		end
		if ability == "Slide" then
			self:_endSlide()
		elseif ability == "WallRun" then
			self:_endWallRun()
		end
	end)

	local function bindCharacter(character: Model)
		-- Clean up any constraint left over from the previous character.
		self:_endSlide()
		self:_endWallRun()

		self.character = character
		self.humanoid = character:WaitForChild("Humanoid") :: Humanoid
		self.root = character:WaitForChild("HumanoidRootPart") :: BasePart
		self.airJumpsUsed = 0
		self.wallChain = 0
		self.lastWallInstance = nil
	end

	self.player.CharacterAdded:Connect(bindCharacter)
	if self.player.Character then
		bindCharacter(self.player.Character)
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		self:_update(deltaTime)
	end)
end

--[[
	Raycast-based grounding.

	Deliberately not Humanoid:GetState(). The Humanoid reports Freefall for a
	frame or two whenever a LinearVelocity takes over its movement, so a
	state-based check would cancel the slide on the frame it started — which is
	exactly the bug this replaced.
]]
function MovementController:_groundRay(distance: number): RaycastResult?
	local root = self.root
	if not root then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.character :: Instance }
	params.IgnoreWater = true

	return Workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), params)
end

function MovementController:_isGrounded(): boolean
	return self:_groundRay(GROUND_RAY_LENGTH) ~= nil
end

function MovementController:_heightAboveGround(): number
	local hit = self:_groundRay(60)
	if not hit or not self.root then
		return math.huge
	end
	return self.root.Position.Y - hit.Position.Y
end

--[[
	Creates or updates a velocity constraint on the root.

	`preserveY` keeps the character's own vertical velocity so gravity keeps
	working; abilities that mean to cancel gravity pass an explicit Y instead.
]]
function MovementController:_applyVelocity(
	name: string,
	existing: LinearVelocity?,
	velocity: Vector3
): LinearVelocity?
	local root = self.root
	if not root then
		return nil
	end

	local force = existing
	if not force or not force.Parent then
		local attachment = root:FindFirstChild(`{name}Attachment`) :: Attachment?
		if not attachment then
			attachment = Instance.new("Attachment")
			attachment.Name = `{name}Attachment`
			attachment.Parent = root
		end

		force = Instance.new("LinearVelocity")
		force.Name = name
		force.Attachment0 = attachment
		-- Finite, not math.huge: see Config/Movement.
		force.MaxForce = MovementConfig.ConstraintForce
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		force.Parent = root
	end
	(force :: LinearVelocity).VectorVelocity = velocity
	return force
end

function MovementController:_update(deltaTime: number)
	local humanoid, root = self.humanoid, self.root
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local input = self.input:GetState()
	local now = os.clock()

	if self:_isGrounded() then
		self.lastGroundedAt = now
		self.airJumpsUsed = 0
		-- Touching the ground clears the wall chain, which is what stops a
		-- player alternating two walls to climb out of an arena.
		self.wallChain = 0
		self.lastWallInstance = nil
	end

	if self.input:Consume("Slide") then
		self:_tryStartSlide()
	end

	if self.input:Consume("Dash") then
		self:_tryDash()
	end

	if self.input:Consume("Jump") then
		-- A jump while on a wall is a wall jump, not an air jump.
		if self.wallRunning then
			self:_wallJump()
		else
			self:_tryDoubleJump()
		end
	end

	if self.sliding then
		self:_updateSlide(deltaTime)
	elseif self.wallRunning then
		self:_updateWallRun(deltaTime)
	else
		self:_tryStartWallRun()

		-- Sprint only applies while moving forward and not aiming, so it never
		-- silently improves strafe speed in a firefight.
		local wantsSprint = input.sprinting and not input.aiming
		humanoid.WalkSpeed = if input.crouching
			then MovementConfig.CrouchSpeed
			elseif wantsSprint then MovementConfig.SprintSpeed
			else MovementConfig.BaseWalkSpeed
	end

	if self.hud then
		self.hud:SetAbilityCooldowns({
			Dash = math.clamp((now - self.lastDashAt) / MovementConfig.Dash.Cooldown, 0, 1),
			Slide = math.clamp((now - self.lastSlideAt) / MovementConfig.Slide.Cooldown, 0, 1),
			DoubleJump = if self.airJumpsUsed < MovementConfig.DoubleJump.MaxAirJumps then 1 else 0,
		})
	end
end

-- Slide ---------------------------------------------------------------------

function MovementController:_tryStartSlide()
	local root, humanoid = self.root, self.humanoid
	if not root or not humanoid or self.sliding or self.wallRunning then
		return
	end

	local now = os.clock()
	if now - self.lastSlideAt < MovementConfig.Slide.Cooldown then
		return
	end

	if not self:_isGrounded() then
		return
	end

	local horizontal = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	if horizontal.Magnitude < MovementConfig.Slide.MinimumEntrySpeed then
		return
	end

	self.sliding = true
	self.lastSlideAt = now
	self.slideStartedAt = now
	self.slideVelocity = horizontal.Unit * MovementConfig.Slide.InitialSpeed

	-- WalkSpeed 0 stops the Humanoid's own mover from fighting the constraint.
	-- HipHeight is deliberately NOT changed: dropping it makes the character
	-- fall to the new height, which breaks ground contact at exactly the wrong
	-- moment. The camera carries the crouch read instead.
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	self.camera:SetHeightOffset(MovementConfig.Slide.CameraHeightDelta)

	self.slideForce = self:_applyVelocity(
		"SlideVelocity",
		self.slideForce,
		Vector3.new(self.slideVelocity.X, root.AssemblyLinearVelocity.Y, self.slideVelocity.Z)
	)

	self:_request("Slide", self.slideVelocity.Unit)
	self.camera:AddShake(0.08)
end

function MovementController:_updateSlide(deltaTime: number)
	local root = self.root
	if not root then
		return self:_endSlide()
	end

	local config = MovementConfig.Slide
	local now = os.clock()

	-- Downhill slopes accelerate the slide; uphill bleeds it faster.
	local ground = self:_groundRay(GROUND_RAY_LENGTH)
	local slopeAcceleration = 0
	if ground then
		slopeAcceleration = self.slideVelocity.Unit:Dot(-ground.Normal) * config.SlopeAcceleration
	end

	local speed = math.clamp(
		self.slideVelocity.Magnitude + (slopeAcceleration - config.Friction) * deltaTime,
		0,
		config.MaximumSpeed
	)
	self.slideVelocity = self.slideVelocity.Unit * speed

	-- Keep the character's own Y so it still falls onto ramps and ledges.
	self.slideForce = self:_applyVelocity(
		"SlideVelocity",
		self.slideForce,
		Vector3.new(self.slideVelocity.X, root.AssemblyLinearVelocity.Y, self.slideVelocity.Z)
	)

	-- The opening grace window: starting a slide disturbs ground contact, and
	-- without this the exit check fires on the first frame.
	if now - self.slideStartedAt < config.StartGrace then
		return
	end

	local expired = now - self.slideStartedAt > config.MaximumDuration
	if speed < config.MinimumExitSpeed or expired or not self:_isGrounded() then
		self:_endSlide()
	end
end

function MovementController:_endSlide()
	if not self.sliding then
		return
	end
	self.sliding = false

	if self.slideForce then
		self.slideForce:Destroy()
		self.slideForce = nil
	end

	local humanoid = self.humanoid
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = MovementConfig.BaseWalkSpeed
	end

	self.camera:SetHeightOffset(0)
end

-- Wall run ------------------------------------------------------------------

--[[
	Looks for a runnable wall to the left or right.
	Returns the side (-1 or 1), the surface normal, and the part.
]]
function MovementController:_detectWall(): (number?, Vector3?, BasePart?)
	local root = self.root
	if not root then
		return nil, nil, nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.character :: Instance }
	params.IgnoreWater = true

	local right = root.CFrame.RightVector
	local distance = MovementConfig.WallRun.DetectionDistance

	for _, side in { -1, 1 } do
		local hit = Workspace:Raycast(root.Position, right * side * distance, params)
		if hit then
			-- Near-vertical surfaces only. A shallow slope is a ramp, and
			-- letting players wall run up ramps looks like a bug.
			if math.abs(hit.Normal.Y) < 0.3 then
				return side, hit.Normal, hit.Instance
			end
		end
	end

	return nil, nil, nil
end

function MovementController:_tryStartWallRun()
	local root = self.root
	if not root or self.sliding or self.wallRunning then
		return
	end

	local config = MovementConfig.WallRun
	local now = os.clock()

	if now - self.lastWallAt < config.Cooldown then
		return
	end

	-- Wall running is an air move. On the ground you are just running.
	if self:_isGrounded() then
		return
	end

	if self:_heightAboveGround() < config.MinimumHeightAboveGround then
		return
	end

	-- The hard stop on climbing out of bounds by alternating walls.
	if self.wallChain >= MovementConfig.Validation.MaxWallChain then
		return
	end

	local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	if velocity.Magnitude < config.MinimumEntrySpeed then
		return
	end

	local side, normal, instance = self:_detectWall()
	if not side or not normal or not instance then
		return
	end

	-- The same wall twice in a row would be an infinite ladder.
	if instance == self.lastWallInstance then
		return
	end

	-- Must be travelling ALONG the wall, not into it.
	local tangent = self:_wallTangent(normal, velocity)
	if velocity.Unit:Dot(tangent) < config.MinimumAlignment then
		return
	end

	self.wallRunning = true
	self.wallStartedAt = now
	self.wallNormal = normal
	self.wallSide = side
	self.wallChain += 1
	self.lastWallInstance = instance

	local humanoid = self.humanoid
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.AutoRotate = false
	end

	self.wallForce = self:_applyVelocity(
		"WallRunVelocity",
		self.wallForce,
		tangent * config.Speed + Vector3.new(0, config.AttachBoost, 0)
	)

	self.camera:SetRoll(-side * config.CameraTilt)
	self.camera:AddShake(0.06)
	self:_request("WallRun", tangent)
end

--[[
	The direction of travel along a wall: the wall's surface projected onto the
	horizontal plane, pointing whichever way the player is already moving.
]]
function MovementController:_wallTangent(normal: Vector3, velocity: Vector3): Vector3
	local flatNormal = (normal * Vector3.new(1, 0, 1))
	if flatNormal.Magnitude < 0.01 then
		return velocity.Unit
	end
	flatNormal = flatNormal.Unit

	local tangent = Vector3.new(-flatNormal.Z, 0, flatNormal.X)
	if velocity.Magnitude > 0.01 and tangent:Dot(velocity.Unit) < 0 then
		tangent = -tangent
	end
	return tangent
end

function MovementController:_updateWallRun(deltaTime: number)
	local root = self.root
	if not root then
		return self:_endWallRun()
	end

	local config = MovementConfig.WallRun
	local now = os.clock()

	if now - self.wallStartedAt > config.MaximumDuration then
		return self:_endWallRun()
	end

	-- Re-confirm the wall every frame. Running off the end of one drops you,
	-- which is the whole appeal of the move.
	local side, normal, instance = self:_detectWall()
	if not side or not normal or side ~= self.wallSide or instance ~= self.lastWallInstance then
		return self:_endWallRun()
	end

	self.wallNormal = normal

	local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local tangent =
		self:_wallTangent(normal, if velocity.Magnitude > 0.01 then velocity else root.CFrame.LookVector)

	-- Reduced gravity rather than none: a wall run that holds height is a
	-- platform, and players will park on it.
	local currentY = root.AssemblyLinearVelocity.Y
	local descend = currentY - Workspace.Gravity * config.GravityScale * deltaTime

	-- Hold the character lightly against the wall so it does not drift off.
	local adhesion = -normal * 4

	self.wallForce = self:_applyVelocity(
		"WallRunVelocity",
		self.wallForce,
		tangent * config.Speed + adhesion + Vector3.new(0, descend, 0)
	)

	if self:_isGrounded() then
		self:_endWallRun()
	end
end

function MovementController:_endWallRun()
	if not self.wallRunning then
		return
	end
	self.wallRunning = false
	self.lastWallAt = os.clock()

	if self.wallForce then
		self.wallForce:Destroy()
		self.wallForce = nil
	end

	local humanoid = self.humanoid
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = MovementConfig.BaseWalkSpeed
	end

	self.camera:SetRoll(0)
end

--[[
	The sanctioned wallhop: launching off a wall refunds the air jump, once per
	wall. The glitch gives you one per seam, which is how players climb forever.
]]
function MovementController:_wallJump()
	local root = self.root
	if not root or not self.wallRunning then
		return
	end

	local config = MovementConfig.WallRun.WallJump
	local now = os.clock()
	if now - self.lastWallJumpAt < config.Cooldown then
		return
	end
	self.lastWallJumpAt = now

	local normal = self.wallNormal
	self:_endWallRun()

	root.AssemblyLinearVelocity = normal * config.OutwardSpeed + Vector3.new(0, config.UpwardSpeed, 0)

	if config.RefundsAirJump then
		self.airJumpsUsed = 0
	end

	self:_request("WallJump", normal)
	self.camera:AddShake(0.14)
end

-- Jump and dash -------------------------------------------------------------

function MovementController:_tryDoubleJump()
	local humanoid, root = self.humanoid, self.root
	if not humanoid or not root then
		return
	end

	local now = os.clock()

	-- Coyote time: a jump shortly after leaving the ground is a ground jump,
	-- handled by the engine, so it must not consume the air jump.
	if self:_isGrounded() or now - self.lastGroundedAt <= MovementConfig.DoubleJump.CoyoteTime then
		return
	end

	if self.airJumpsUsed >= MovementConfig.DoubleJump.MaxAirJumps then
		return
	end

	self.airJumpsUsed += 1

	local velocity = root.AssemblyLinearVelocity
	if MovementConfig.DoubleJump.CancelFallVelocity and velocity.Y < 0 then
		velocity = Vector3.new(velocity.X, 0, velocity.Z)
	end
	root.AssemblyLinearVelocity = velocity + Vector3.new(0, MovementConfig.DoubleJump.Power, 0)

	self:_request("DoubleJump", Vector3.yAxis)
	self.camera:AddShake(0.05)
end

function MovementController:_tryDash()
	local root = self.root
	if not root then
		return
	end

	local now = os.clock()
	if now - self.lastDashAt < MovementConfig.Dash.Cooldown then
		return
	end

	-- Dash follows the movement stick when there is one, and the camera when
	-- standing still, so a panic dash always goes somewhere sensible.
	local direction = self.input:GetMoveDirection()
	if direction.Magnitude < 0.1 then
		local _, look = self.camera:GetAimRay()
		direction = look * Vector3.new(1, 0, 1)
	end
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit

	local config = MovementConfig.Dash
	self.lastDashAt = now
	self.dashUntil = now + config.Duration

	-- A wall run cannot survive a dash; dashing off a wall is a valid exit.
	self:_endWallRun()

	-- VerticalHold cancels gravity for the dash so an air dash stays flat and
	-- readable. Without it the dash arcs into the floor and reads as a stumble.
	local verticalVelocity = if config.VerticalHold then 0 else root.AssemblyLinearVelocity.Y
	local force = self:_applyVelocity(
		"DashVelocity",
		nil,
		direction * config.Speed + Vector3.new(0, verticalVelocity, 0)
	)

	task.delay(config.Duration, function()
		if force and force.Parent then
			force:Destroy()
		end
	end)

	self:_request("Dash", direction)
	self.camera:AddShake(0.12)

	if self.hud then
		self.hud:FlashDodge(config.InvulnerabilityWindow)
	end
end

function MovementController:_request(ability: string, direction: Vector3)
	self.requestRemote:FireServer({
		ability = ability,
		direction = direction,
		clientTime = Workspace:GetServerTimeNow(),
	})
end

function MovementController:IsSliding(): boolean
	return self.sliding
end

function MovementController:IsWallRunning(): boolean
	return self.wallRunning
end

return MovementController
