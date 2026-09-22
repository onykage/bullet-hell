--!strict
--[[
	MovementController.luau

	Slide, double jump, and dash — predicted locally, validated by the server.

	Design notes:

	  Slide  — entered from a sprint by pressing crouch. Carries momentum that
	           bleeds off against friction, accelerates downhill, and ends when
	           it drops below a minimum speed. The camera drops with it so the
	           speed reads visually. It is a commitment, not a toggle.

	  Double jump — one air jump, with the fall velocity cancelled first so a
	           late press still saves you. Coyote time means walking off a ledge
	           does not silently eat your ground jump.

	  Dash   — a short burst with server-granted invulnerability frames. This is
	           the dodge the bullet-hell layer is balanced around (§5.2).

	Everything reads Config/Movement, the same module the server validates
	against, so a tuning change can never desync feel from authority.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Network.Events)
local MovementConfig = require(Shared.Config.Movement)

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
	self.character = nil :: Model?
	self.humanoid = nil :: Humanoid?
	self.root = nil :: BasePart?
	self.slideForce = nil :: LinearVelocity?
end

function MovementController:Start()
	self.requestRemote = Events.get("C2S_MovementAbility")
	self.responseRemote = Events.get("S2C_MovementResponse")

	self.responseRemote.OnClientEvent:Connect(function(ability: string, approved: boolean)
		-- A denial means the client and server disagreed. Rather than snapping
		-- the player (which feels awful and is usually the server being
		-- cautious), the prediction is simply ended early.
		if not approved and ability == "Slide" then
			self:_endSlide()
		end
	end)

	local function bindCharacter(character: Model)
		self.character = character
		self.humanoid = character:WaitForChild("Humanoid") :: Humanoid
		self.root = character:WaitForChild("HumanoidRootPart") :: BasePart
		self.airJumpsUsed = 0
		self.sliding = false

		self.humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
				self.airJumpsUsed = 0
				self.lastGroundedAt = os.clock()
			end
		end)
	end

	self.player.CharacterAdded:Connect(bindCharacter)
	if self.player.Character then
		bindCharacter(self.player.Character)
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		self:_update(deltaTime)
	end)
end

function MovementController:_isGrounded(): boolean
	local humanoid = self.humanoid
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.RunningNoPhysics
		or state == Enum.HumanoidStateType.Landed
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
	end

	if self.input:Consume("Slide") then
		self:_tryStartSlide()
	end

	if self.input:Consume("Dash") then
		self:_tryDash()
	end

	if self.input:Consume("Jump") then
		self:_tryDoubleJump()
	end

	if self.sliding then
		self:_updateSlide(deltaTime)
	else
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

function MovementController:_tryStartSlide()
	local root, humanoid = self.root, self.humanoid
	if not root or not humanoid or self.sliding then
		return
	end

	local now = os.clock()
	if now - self.lastSlideAt < MovementConfig.Slide.Cooldown then
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

	humanoid.HipHeight += MovementConfig.Slide.HipHeightDelta
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false

	-- A LinearVelocity drives the slide so it interacts with the physics world
	-- (ramps, ledges) instead of teleporting the character.
	local attachment = root:FindFirstChild("SlideAttachment") :: Attachment?
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "SlideAttachment"
		attachment.Parent = root
	end

	local force = Instance.new("LinearVelocity")
	force.Name = "SlideVelocity"
	force.Attachment0 = attachment
	force.MaxForce = math.huge
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	force.VectorVelocity = self.slideVelocity
	force.Parent = root
	self.slideForce = force

	self:_request("Slide", self.slideVelocity.Unit)
	self.camera:AddShake(0.08)
end

function MovementController:_updateSlide(deltaTime: number)
	local root, humanoid = self.root, self.humanoid
	if not root or not humanoid then
		return self:_endSlide()
	end

	local config = MovementConfig.Slide
	local now = os.clock()

	-- Downhill slopes accelerate the slide; uphill bleeds it faster.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { self.character :: Instance }
	local ground = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rayParams)

	local slopeAcceleration = 0
	if ground then
		local slope = self.slideVelocity.Unit:Dot(-ground.Normal)
		slopeAcceleration = slope * config.SlopeAcceleration
	end

	local speed = self.slideVelocity.Magnitude
	speed += (slopeAcceleration - config.Friction) * deltaTime
	speed = math.clamp(speed, 0, config.MaximumSpeed)

	self.slideVelocity = self.slideVelocity.Unit * speed
	if self.slideForce then
		self.slideForce.VectorVelocity = self.slideVelocity
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
		humanoid.HipHeight -= MovementConfig.Slide.HipHeightDelta
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = MovementConfig.BaseWalkSpeed
	end
end

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

	self.lastDashAt = now
	self.dashUntil = now + MovementConfig.Dash.Duration

	local config = MovementConfig.Dash
	local attachment = root:FindFirstChild("DashAttachment") :: Attachment?
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "DashAttachment"
		attachment.Parent = root
	end

	local force = Instance.new("LinearVelocity")
	force.Name = "DashVelocity"
	force.Attachment0 = attachment
	force.MaxForce = math.huge
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	force.VectorVelocity = direction * config.Speed
		+ (if config.VerticalHold then Vector3.zero else Vector3.zero)
	force.Parent = root

	task.delay(config.Duration, function()
		if force.Parent then
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

return MovementController
