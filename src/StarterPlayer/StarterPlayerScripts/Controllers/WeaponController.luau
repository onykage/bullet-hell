--!strict
--[[
	WeaponController.luau

	Predicted firing and the first-person viewmodel (§12.4).

	The client fires the instant the trigger is pulled: recoil, tracer, sound,
	spread bloom, and a predicted ammo decrement all happen locally on that
	frame. It then asks the server, which independently re-runs the whole
	validation chain and replies with the authoritative ammo count. If the two
	disagree, the server wins and the client snaps — the prediction exists to
	remove input latency, not to decide anything (§12.1).

	Spread is generated from the SAME shared math the server validates against,
	so honest clients are never rejected for a legal pellet spread.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Events = require(Shared.Network.Events)
local WeaponMath = require(Shared.Combat.WeaponMath)
local Weapons = require(Shared.Config.Weapons)

local WeaponController = {}

function WeaponController:Init(context)
	self.player = context.player
	self.input = context.controllers.InputController
	self.camera = context.controllers.CameraController
	self.effects = context.controllers.EffectsController
	self.hud = context.controllers.HUDController
	self.movement = context.controllers.MovementController

	self.weaponId = nil :: string?
	self.definition = nil :: any
	self.ammo = 0
	self.reserve = 0
	self.bloom = 0
	self.lastShotAt = 0
	self.sequenceId = 0
	self.reloading = false
	self.loadout = {} :: { string }
	self.slotIndex = 1
	self.burstRemaining = 0
	self.semiLatch = false

	self.rng = Random.new()
	self.viewmodel = nil :: Model?
	self.viewmodelSpec = nil :: any
	self.viewmodelSway = CFrame.identity
end

function WeaponController:Start()
	self.fireRemote = Events.get("C2S_FireWeapon")
	self.reloadRemote = Events.get("C2S_ReloadWeapon")
	self.equipRemote = Events.get("C2S_EquipWeapon")
	self.ammoRemote = Events.get("S2C_AmmoChanged")
	self.confirmRemote = Events.get("S2C_FireConfirmed")
	self.rejectRemote = Events.get("S2C_FireRejected")
	self.loadoutRemote = Events.get("C2S_GetLoadout")

	-- The server is the source of truth for ammo; the local count is a guess
	-- that gets corrected here every shot.
	self.ammoRemote.OnClientEvent:Connect(function(weaponId: string, ammo: number, reserve: number)
		if weaponId ~= self.weaponId then
			self:_setWeapon(weaponId)
		end
		self.ammo = ammo
		self.reserve = reserve
		self.reloading = false
		self:_pushHud()
	end)

	self.confirmRemote.OnClientEvent:Connect(
		function(shooterUserId: number, weaponId: string, origin: Vector3, endpoints: { Vector3 })
			-- Our own tracer was already drawn by prediction; only draw for others.
			if shooterUserId == self.player.UserId then
				return
			end
			local definition = Weapons.get(weaponId)
			for _, endpoint in endpoints do
				self.effects:SpawnTracer(
					origin,
					endpoint,
					if definition then definition.Viewmodel.Color else nil
				)
			end
		end
	)

	self.rejectRemote.OnClientEvent:Connect(function()
		-- Presentation only. The authoritative ammo correction arrives
		-- separately; this just stops the predicted burst.
		self.burstRemaining = 0
	end)

	local response = self.loadoutRemote:InvokeServer()
	self.loadout = response.loadout or {}
	if response.equipped then
		self:_setWeapon(response.equipped)
	elseif self.loadout[1] then
		self:RequestEquip(self.loadout[1])
	end

	RunService.RenderStepped:Connect(function(deltaTime)
		self:_update(deltaTime)
	end)
end

function WeaponController:_setWeapon(weaponId: string)
	local definition = Weapons.get(weaponId)
	if not definition then
		return
	end

	self.weaponId = weaponId
	self.definition = definition
	self.bloom = 0
	self.burstRemaining = 0

	local index = table.find(self.loadout, weaponId)
	if index then
		self.slotIndex = index
	end

	self:_buildViewmodel(definition)
	self:_pushHud()
end

function WeaponController:RequestEquip(weaponId: string)
	self.equipRemote:FireServer({ weaponId = weaponId })
end

function WeaponController:_update(deltaTime: number)
	local definition = self.definition
	if not definition then
		return
	end

	local stats = definition.BaseStats
	local input = self.input:GetState()

	self.bloom = WeaponMath.decayBloom(stats, self.bloom, deltaTime)

	if self.input:Consume("Reload") then
		self:_requestReload()
	end

	local slot = self.input:ConsumeSlot()
	if slot and self.loadout[slot] and self.loadout[slot] ~= self.weaponId then
		self:RequestEquip(self.loadout[slot])
	end

	if self.input:Consume("SwapNext") then
		self:_cycle(1)
	elseif self.input:Consume("SwapPrevious") then
		self:_cycle(-1)
	end

	-- Aiming narrows the FOV and the cone; sliding forbids aiming, which keeps
	-- slide a movement choice rather than a free accuracy window.
	local canAim = input.aiming and not self.movement:IsSliding()
	self.camera:SetFieldOfView(if canAim then stats.AimFieldOfView else 70)

	self:_updateViewmodel(deltaTime, canAim)

	if self.reloading or self.ammo <= 0 then
		if input.firing and self.ammo <= 0 and not self.reloading then
			self:_requestReload()
		end
		return
	end

	local wantsToFire = false
	if definition.FireMode == "Auto" then
		wantsToFire = input.firing
	elseif definition.FireMode == "Semi" then
		if input.firing and not self.semiLatch then
			wantsToFire = true
			self.semiLatch = true
		end
	elseif definition.FireMode == "Burst" then
		if input.firing and not self.semiLatch then
			self.burstRemaining = definition.BurstCount or 3
			self.semiLatch = true
		end
		wantsToFire = self.burstRemaining > 0
	end

	if not input.firing then
		self.semiLatch = false
	end

	if wantsToFire then
		self:_tryFire(canAim)
	end
end

function WeaponController:_cycle(direction: number)
	if #self.loadout == 0 then
		return
	end
	local nextIndex = ((self.slotIndex - 1 + direction) % #self.loadout) + 1
	self:RequestEquip(self.loadout[nextIndex])
end

function WeaponController:_tryFire(isAiming: boolean)
	local definition = self.definition
	local stats = definition.BaseStats
	local now = os.clock()

	if now - self.lastShotAt < 1 / stats.FireRate then
		return
	end
	self.lastShotAt = now

	if self.burstRemaining > 0 then
		self.burstRemaining -= 1
	end

	local origin, look = self.camera:GetAimRay()
	local spread = WeaponMath.currentSpread(stats, self.bloom, isAiming)

	local directions = table.create(stats.Pellets)
	for _ = 1, stats.Pellets do
		table.insert(directions, WeaponMath.applySpread(look, spread, self.rng))
	end

	-- Predicted presentation, this frame.
	self.ammo = math.max(0, self.ammo - 1)
	self.bloom = WeaponMath.addBloom(stats, self.bloom)
	self.camera:AddRecoil(stats.RecoilVertical, stats.RecoilHorizontal)
	self.camera:AddShake(0.05 + stats.RecoilVertical * 0.02)
	self:_pushHud()

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {
		self.player.Character :: Instance,
		Workspace:FindFirstChild("Viewmodel") :: Instance,
	}
	rayParams.CollisionGroup = Contract.CollisionGroups.Default

	for _, direction in directions do
		local result = Workspace:Raycast(origin, direction * stats.Range, rayParams)
		local endpoint = if result then result.Position else origin + direction * stats.Range
		self.effects:SpawnTracer(self:_muzzlePosition() or origin, endpoint, definition.Viewmodel.Color)
		if result then
			self.effects:SpawnImpact(result.Position, result.Normal)
		end
	end

	self.effects:MuzzleFlash(self:_muzzlePosition())

	self.sequenceId += 1
	self.fireRemote:FireServer({
		sequenceId = self.sequenceId,
		origin = origin,
		directions = directions,
		clientTime = Workspace:GetServerTimeNow(),
	})
end

function WeaponController:_requestReload()
	local definition = self.definition
	if not definition or self.reloading then
		return
	end
	if self.ammo >= definition.BaseStats.MagazineSize or self.reserve <= 0 then
		return
	end

	self.reloading = true
	self:_pushHud()
	self.reloadRemote:FireServer()
end

function WeaponController:_pushHud()
	if not self.hud or not self.definition then
		return
	end
	self.hud:SetWeapon({
		displayName = self.definition.DisplayName,
		ammo = self.ammo,
		magazine = self.definition.BaseStats.MagazineSize,
		reserve = self.reserve,
		reloading = self.reloading,
		spread = self.bloom + self.definition.BaseStats.SpreadDegrees,
	})
end

--[[
	Graybox viewmodel: primitives assembled from the weapon's ViewmodelSpec.
	Replaced wholesale by a Studio-authored model + attachments (§R7); the spec
	is the handoff shape, so only this function changes.
]]
function WeaponController:_buildViewmodel(definition: any)
	if self.viewmodel then
		self.viewmodel:Destroy()
	end

	local spec = definition.Viewmodel

	local model = Instance.new("Model")
	model.Name = "Viewmodel"

	local function piece(name: string, size: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CollisionGroup = Contract.CollisionGroups.Viewmodel
		part.Parent = model
		return part
	end

	local body = piece("Body", spec.BodySize, spec.Color)
	piece("Barrel", spec.BarrelSize, spec.Color:Lerp(Color3.new(0, 0, 0), 0.35))
	piece("Grip", spec.GripSize, spec.Color:Lerp(Color3.new(0, 0, 0), 0.5))

	local muzzle = Instance.new("Attachment")
	muzzle.Name = Contract.WeaponAttachments.Muzzle
	muzzle.Position = spec.BarrelOffset + Vector3.new(0, 0, -spec.BarrelSize.Z * 0.5)
	muzzle.Parent = body

	model.PrimaryPart = body
	model.Parent = Workspace.CurrentCamera

	self.viewmodel = model
	self.viewmodelSpec = spec
	self.viewmodelSway = CFrame.identity
end

function WeaponController:_updateViewmodel(deltaTime: number, isAiming: boolean)
	local model = self.viewmodel
	local spec = self.viewmodelSpec
	local camera = Workspace.CurrentCamera
	if not model or not spec or not camera or not model.PrimaryPart then
		return
	end

	local target = if isAiming then spec.AimOffset else spec.HoldOffset

	-- Bob and sway are cosmetic, and deliberately subtle: they must never move
	-- the muzzle far enough to confuse where the shot went.
	local time = os.clock()
	local moving = self.input:GetMoveDirection().Magnitude > 0.1
	local bobAmount = if moving then (if isAiming then 0.012 else 0.035) else 0.006
	local bob = CFrame.new(math.sin(time * 9) * bobAmount, math.sin(time * 18) * bobAmount * 0.6, 0)

	self.viewmodelSway = self.viewmodelSway:Lerp(target * bob, math.min(1, 16 * deltaTime))

	local root = camera.CFrame * self.viewmodelSway
	model:PivotTo(root)

	local body = model.PrimaryPart
	local barrel = model:FindFirstChild("Barrel") :: BasePart?
	local grip = model:FindFirstChild("Grip") :: BasePart?
	if barrel then
		barrel.CFrame = body.CFrame * CFrame.new(spec.BarrelOffset)
	end
	if grip then
		grip.CFrame = body.CFrame * CFrame.new(spec.GripOffset)
	end
end

function WeaponController:_muzzlePosition(): Vector3?
	local model = self.viewmodel
	local body = model and model.PrimaryPart
	if not body then
		return nil
	end
	local muzzle = body:FindFirstChild(Contract.WeaponAttachments.Muzzle) :: Attachment?
	return if muzzle then muzzle.WorldPosition else body.Position
end

return WeaponController
