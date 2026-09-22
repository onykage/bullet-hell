--!strict
--[[
	WeaponService.luau

	Server-authoritative firing (§12.4, §15.1).

	The client predicts presentation — recoil, tracer, sound, hitmarker — the
	instant the trigger is pulled, because waiting for the server feels broken.
	It does not decide anything. This service independently validates:

	    rate limit -> payload schema -> equipped weapon -> reload state
	    -> ammunition -> fire cadence -> shot origin -> aim deviation
	    -> raycast -> permission -> damage

	A rejected shot returns a coarse code; the detailed reason stays in the
	server log so validation logic is not handed to exploiters (§C4).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Contract = require(Shared.Contract)
local DamageCalculator = require(Shared.Combat.DamageCalculator)
local Events = require(Shared.Network.Events)
local RateLimits = require(Shared.Network.RateLimits)
local Schemas = require(Shared.Network.Schemas)
local WeaponMath = require(Shared.Combat.WeaponMath)
local Weapons = require(Shared.Config.Weapons)

-- How far the reported muzzle origin may sit from the player's head before the
-- shot is refused. Generous enough for viewmodel offset and interpolation,
-- small enough that it cannot be used to shoot around corners.
local MAX_ORIGIN_OFFSET = 14

local WeaponService = {}

type WeaponState = {
	weaponId: string,
	ammo: number,
	reserve: number,
	reloading: boolean,
	reloadToken: number,
	lastShotAt: number,
	lastSequenceId: number,
	equippedAt: number,
}

function WeaponService:Init(context)
	self.states = {} :: { [Player]: WeaponState }
	self.combat = context.services.CombatService
	self.playerData = context.services.PlayerDataService
end

function WeaponService:Start()
	self.fireRemote = Events.get("C2S_FireWeapon")
	self.reloadRemote = Events.get("C2S_ReloadWeapon")
	self.equipRemote = Events.get("C2S_EquipWeapon")
	self.confirmRemote = Events.get("S2C_FireConfirmed")
	self.rejectRemote = Events.get("S2C_FireRejected")
	self.ammoRemote = Events.get("S2C_AmmoChanged")
	self.loadoutRemote = Events.get("C2S_GetLoadout")

	self.loadoutRemote.OnServerInvoke = function(player)
		return {
			loadout = self.playerData:GetLoadout(player),
			equipped = self:_currentWeaponId(player),
		}
	end

	self.fireRemote.OnServerEvent:Connect(function(player, payload)
		self:_handleFire(player, payload)
	end)

	self.reloadRemote.OnServerEvent:Connect(function(player)
		self:_handleReload(player)
	end)

	self.equipRemote.OnServerEvent:Connect(function(player, payload)
		self:_handleEquip(player, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- A fresh character means a fresh weapon state: no carrying a
			-- mid-reload or a stale cadence timestamp across a death.
			task.defer(function()
				self:_equip(player, self:_currentWeaponId(player) or Weapons.DefaultLoadout[1])
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.states[player] = nil
		RateLimits.clearPlayer(player.UserId)
	end)
end

function WeaponService:_currentWeaponId(player: Player): string?
	local state = self.states[player]
	return state and state.weaponId
end

function WeaponService:GetState(player: Player): WeaponState?
	return self.states[player]
end

function WeaponService:_reject(player: Player, code: number, detail: string)
	warn(`[WeaponService] rejected {player.Name}: {detail}`)
	self.rejectRemote:FireClient(player, code)
end

function WeaponService:_equip(player: Player, weaponId: string?)
	if not weaponId then
		return
	end

	local definition = Weapons.get(weaponId)
	if not definition then
		return
	end

	self.states[player] = {
		weaponId = weaponId,
		ammo = definition.BaseStats.MagazineSize,
		reserve = definition.BaseStats.MagazineSize * 6,
		reloading = false,
		reloadToken = 0,
		lastShotAt = 0,
		lastSequenceId = -1,
		equippedAt = os.clock(),
	}

	self.ammoRemote:FireClient(
		player,
		weaponId,
		definition.BaseStats.MagazineSize,
		self.states[player].reserve
	)
end

function WeaponService:_handleEquip(player: Player, payload: any)
	if not RateLimits.consume(player.UserId, "EquipWeapon") then
		return self:_reject(player, Schemas.RejectionCodes.RateLimited, "equip rate limited")
	end

	local ok, cleaned = Schemas.validateEquipRequest(payload)
	if not ok then
		return self:_reject(player, Schemas.RejectionCodes.Malformed, `equip payload: {cleaned}`)
	end

	if not self.playerData:CanEquip(player, cleaned.weaponId) then
		return self:_reject(
			player,
			Schemas.RejectionCodes.NotPermitted,
			`equip {cleaned.weaponId} not in loadout`
		)
	end

	self:_equip(player, cleaned.weaponId)
end

function WeaponService:_handleReload(player: Player)
	if not RateLimits.consume(player.UserId, "ReloadWeapon") then
		return
	end

	local state = self.states[player]
	if not state or state.reloading then
		return
	end

	local definition = Weapons.expect(state.weaponId)
	if state.ammo >= definition.BaseStats.MagazineSize or state.reserve <= 0 then
		return
	end

	state.reloading = true
	state.reloadToken += 1
	local token = state.reloadToken

	task.delay(definition.BaseStats.ReloadTime, function()
		local current = self.states[player]
		-- The reload is void if the player died, swapped weapons, or started
		-- another reload in the meantime (§C6 "reload interruption").
		if not current or current ~= state or current.reloadToken ~= token then
			return
		end

		local needed = definition.BaseStats.MagazineSize - current.ammo
		local taken = math.min(needed, current.reserve)
		current.ammo += taken
		current.reserve -= taken
		current.reloading = false

		self.ammoRemote:FireClient(player, current.weaponId, current.ammo, current.reserve)
	end)
end

function WeaponService:_handleFire(player: Player, payload: any)
	if not RateLimits.consume(player.UserId, "FireWeapon") then
		return self:_reject(player, Schemas.RejectionCodes.RateLimited, "fire rate limited")
	end

	local ok, cleaned = Schemas.validateFireRequest(payload)
	if not ok then
		return self:_reject(player, Schemas.RejectionCodes.Malformed, `fire payload: {cleaned}`)
	end

	local state = self.states[player]
	if not state then
		return self:_reject(player, Schemas.RejectionCodes.InvalidState, "no equipped weapon")
	end

	-- Replayed or out-of-order sequence IDs are dropped outright (§C4).
	if cleaned.sequenceId <= state.lastSequenceId then
		return self:_reject(player, Schemas.RejectionCodes.InvalidState, "stale sequenceId")
	end
	state.lastSequenceId = cleaned.sequenceId

	if state.reloading then
		return self:_reject(player, Schemas.RejectionCodes.InvalidState, "firing while reloading")
	end

	if state.ammo <= 0 then
		return self:_reject(player, Schemas.RejectionCodes.InvalidState, "firing with empty magazine")
	end

	local definition = Weapons.expect(state.weaponId)
	local stats = definition.BaseStats

	local now = os.clock()
	if now - state.equippedAt < stats.EquipTime * 0.8 then
		return self:_reject(player, Schemas.RejectionCodes.Cooldown, "firing before equip completed")
	end

	local interval = WeaponMath.minimumShotInterval(stats)
	if state.lastShotAt > 0 and now - state.lastShotAt < interval then
		return self:_reject(player, Schemas.RejectionCodes.Cooldown, "fire rate exceeded")
	end

	if #cleaned.directions ~= stats.Pellets then
		return self:_reject(player, Schemas.RejectionCodes.Malformed, "pellet count mismatch")
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return self:_reject(player, Schemas.RejectionCodes.InvalidState, "no character")
	end

	local entity = self.combat:GetEntity(character)
	if not entity or entity.dead then
		return self:_reject(player, Schemas.RejectionCodes.InvalidState, "firing while dead")
	end

	-- Shot must originate near the player, not across the map.
	if (cleaned.origin - root.Position).Magnitude > MAX_ORIGIN_OFFSET then
		return self:_reject(player, Schemas.RejectionCodes.OutOfRange, "origin too far from character")
	end

	-- Every pellet must lie inside the weapon's own cone, measured against the
	-- volley's mean direction.
	local mean = Vector3.zero
	for _, direction in cleaned.directions do
		mean += direction
	end
	if mean.Magnitude < 0.001 then
		return self:_reject(player, Schemas.RejectionCodes.Malformed, "degenerate direction set")
	end
	mean = mean.Unit

	local maxDeviation = math.rad(WeaponMath.maximumLegalDeviation(stats))
	for _, direction in cleaned.directions do
		if math.acos(math.clamp(direction:Dot(mean), -1, 1)) > maxDeviation then
			return self:_reject(player, Schemas.RejectionCodes.OutOfRange, "pellet outside legal cone")
		end
	end

	state.ammo -= 1
	state.lastShotAt = now
	self.playerData:IncrementStat(player, "ShotsFired", 1)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances =
		{ character, Workspace:FindFirstChild(Contract.Containers.Runtime) }
	rayParams.IgnoreWater = true
	rayParams.CollisionGroup = Contract.CollisionGroups.Default

	local endpoints = table.create(#cleaned.directions)
	local totalDamage = 0

	for _, direction in cleaned.directions do
		local result = Workspace:Raycast(cleaned.origin, direction * stats.Range, rayParams)
		local endpoint = if result then result.Position else cleaned.origin + direction * stats.Range
		table.insert(endpoints, endpoint)

		if not result then
			continue
		end

		local target, regionName, regionMultiplier = self.combat:ResolveHit(result.Instance)
		if not target then
			continue
		end

		local distance = (result.Position - cleaned.origin).Magnitude
		local region = DamageCalculator.regionMultiplier(regionName, regionMultiplier)
		local isCritical = region >= Balance.HitRegions.Head

		local applied = self.combat:ApplyDamage(target.model, {
			attackerUserId = player.UserId,
			sourceId = "weapon",
			weaponId = state.weaponId,
			damageType = definition.DamageType,
			baseDamage = stats.Damage,
			hitPosition = result.Position,
			hitRegion = regionName,
			isCritical = isCritical,
			isPvP = false,
			sequenceId = cleaned.sequenceId,
		}, {
			regionMultiplier = region,
			falloff = WeaponMath.falloffMultiplier(stats, distance),
			multiplicative = if isCritical then stats.CriticalMultiplier else 1,
		}, character)

		if applied then
			totalDamage += applied.applied
		end
	end

	if totalDamage > 0 then
		self.playerData:IncrementStat(player, "DamageDealt", totalDamage)
	end

	-- Ammo is private to the shooter; the tracer is public so teammates can
	-- read where fire is coming from.
	self.ammoRemote:FireClient(player, state.weaponId, state.ammo, state.reserve)
	self.confirmRemote:FireAllClients(player.UserId, state.weaponId, cleaned.origin, endpoints)
end

return WeaponService
