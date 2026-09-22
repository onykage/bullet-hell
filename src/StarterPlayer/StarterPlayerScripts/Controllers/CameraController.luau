--!strict
--[[
	CameraController.luau

	First-person camera, recoil, FOV, and shake (§C3 controllers table).

	Recoil is presentation applied on top of the default camera, not a
	replacement camera. It is also *recoverable*: the kick is pushed onto an
	offset that springs back toward zero, so a burst walks up the screen and
	then settles, which is what makes recoil learnable rather than random.

	Shake amplitude is scaled by a player setting (§17.4 accessibility) and
	never hides gameplay information.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraController = {}

local RECOVERY_RATE = 9 -- how fast the recoil offset springs back
local SHAKE_DECAY = 6

function CameraController:Init(context)
	self.player = context.player
	self.camera = Workspace.CurrentCamera

	self.recoilOffset = Vector2.zero -- degrees, x = horizontal, y = vertical
	self.shake = 0

	-- Movement abilities lean on the camera to communicate state: the slide
	-- drops it, the wall run rolls it. Both ease rather than snap, so entering
	-- and leaving reads as motion instead of a glitch.
	self.heightOffset = 0
	self.targetHeightOffset = 0
	self.roll = 0
	self.targetRoll = 0
	self.baseFieldOfView = 70
	self.targetFieldOfView = 70

	-- Accessibility: 0 disables shake entirely without disabling telegraphs.
	self.shakeScale = 1
end

function CameraController:Start()
	self.player.CameraMode = Enum.CameraMode.LockFirstPerson

	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self.camera = Workspace.CurrentCamera
	end)

	-- Runs after the default camera has written its CFrame, so the offset is
	-- applied on top rather than fought over.
	RunService:BindToRenderStep("BulletHellCamera", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		self:_update(deltaTime)
	end)
end

function CameraController:_update(deltaTime: number)
	local camera = self.camera
	if not camera then
		return
	end

	-- Spring the recoil offset back toward zero.
	local recovery = math.min(1, RECOVERY_RATE * deltaTime)
	self.recoilOffset = self.recoilOffset:Lerp(Vector2.zero, recovery)
	self.shake = math.max(0, self.shake - SHAKE_DECAY * deltaTime * math.max(self.shake, 0.4))

	camera.FieldOfView += (self.targetFieldOfView - camera.FieldOfView) * math.min(1, 12 * deltaTime)

	local ease = math.min(1, 10 * deltaTime)
	self.heightOffset += (self.targetHeightOffset - self.heightOffset) * ease
	self.roll += (self.targetRoll - self.roll) * ease

	local shakeAmount = self.shake * self.shakeScale
	local shakeOffset =
		CFrame.new((math.random() - 0.5) * shakeAmount, (math.random() - 0.5) * shakeAmount, 0)

	camera.CFrame = camera.CFrame
		* CFrame.new(0, self.heightOffset, 0)
		* CFrame.Angles(math.rad(self.recoilOffset.Y), math.rad(self.recoilOffset.X), math.rad(self.roll))
		* shakeOffset
end

--[[
	Vertical camera offset in studs. The slide uses this instead of changing the
	Humanoid's HipHeight: lowering HipHeight makes the character fall to the new
	height, breaking ground contact at exactly the moment the slide needs it.
]]
function CameraController:SetHeightOffset(studs: number)
	self.targetHeightOffset = studs
end

--[[
	Camera roll in degrees, used to lean into a wall run. Eased and capped
	because roll is vestibular: a hard snap is genuinely unpleasant. It scales
	with the same accessibility setting as shake, so a player who turns shake
	off gets no forced roll either.
]]
function CameraController:SetRoll(degrees: number)
	self.targetRoll = math.clamp(degrees, -25, 25) * self.shakeScale
end

--[[
	Applies a recoil kick in degrees. Called by WeaponController the instant the
	shot is predicted, never when the server confirms — waiting would make the
	gun feel disconnected from the trigger (§12.1).
]]
function CameraController:AddRecoil(vertical: number, horizontal: number)
	self.recoilOffset += Vector2.new(horizontal * (if math.random() > 0.5 then 1 else -1), vertical)
end

function CameraController:AddShake(amount: number)
	self.shake = math.min(1.5, self.shake + amount)
end

function CameraController:SetFieldOfView(value: number)
	self.targetFieldOfView = value
end

function CameraController:ResetFieldOfView()
	self.targetFieldOfView = self.baseFieldOfView
end

function CameraController:GetAimRay(): (Vector3, Vector3)
	local camera = self.camera
	if not camera then
		return Vector3.zero, Vector3.zAxis
	end
	return camera.CFrame.Position, camera.CFrame.LookVector
end

return CameraController
