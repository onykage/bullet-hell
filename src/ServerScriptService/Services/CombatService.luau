--!strict
--[[
	CombatService.luau

	The one path through which health changes (§C7).

	Every damage source — hitscan bullets, shotgun pellets, boss patterns, enemy
	attacks — calls `ApplyDamage`. Nothing else in the codebase writes to a
	Humanoid's health or to an entity's health field. That is what makes damage
	auditable, makes floating damage numbers correct by construction, and makes
	the PvE/PvP split enforceable in one place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local DamageCalculator = require(Shared.Combat.DamageCalculator)
local Events = require(Shared.Network.Events)
local Signal = require(Shared.Utility.Signal)
local Types = require(Shared.Types)

type DamageContext = Types.DamageContext
type DamageResult = Types.DamageResult

export type Entity = {
	model: Model,
	entityId: string,
	faction: string, -- "Player" | "Enemy" | "Boss" | "Neutral"
	health: number,
	maxHealth: number,
	humanoid: Humanoid?,
	player: Player?,
	damageReduction: number,
	invulnerableUntil: number,
	dead: boolean,
	resetHealthAfter: number?,
	lastDamagedAt: number,
}

local CombatService = {}

function CombatService:Init()
	self.entities = {} :: { [Model]: Entity }
	self.nextEntityNumber = 0

	-- Other services subscribe rather than being called directly, so the
	-- dependency graph stays one-directional (§13).
	self.Damaged = Signal.new()
	self.Died = Signal.new()
end

function CombatService:Start()
	self.damageDealtRemote = Events.get("S2C_DamageDealt")
	self.damageTakenRemote = Events.get("S2C_DamageTaken")
	self.healthChangedRemote = Events.get("S2C_HealthChanged")
	self.diedRemote = Events.get("S2C_EntityDied")

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			self:RegisterCharacter(player, character)
		end)
		if player.Character then
			self:RegisterCharacter(player, player.Character)
		end
	end)
end

function CombatService:RegisterCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	humanoid.MaxHealth = Balance.Player.MaxHealth
	humanoid.Health = Balance.Player.MaxHealth
	humanoid.BreakJointsOnDeath = false

	self:Register({
		model = character,
		faction = "Player",
		maxHealth = Balance.Player.MaxHealth,
		humanoid = humanoid,
		player = player,
	})

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:Unregister(character)
		end
	end)
end

export type RegisterOptions = {
	model: Model,
	faction: string,
	maxHealth: number,
	humanoid: Humanoid?,
	player: Player?,
	entityId: string?,
	resetHealthAfter: number?,
}

function CombatService:Register(options: RegisterOptions): Entity
	self.nextEntityNumber += 1

	local entity: Entity = {
		model = options.model,
		entityId = options.entityId or `entity_{self.nextEntityNumber}`,
		faction = options.faction,
		health = options.maxHealth,
		maxHealth = options.maxHealth,
		humanoid = options.humanoid,
		player = options.player,
		damageReduction = 0,
		invulnerableUntil = 0,
		dead = false,
		resetHealthAfter = options.resetHealthAfter,
		lastDamagedAt = 0,
	}

	self.entities[options.model] = entity
	return entity
end

function CombatService:Unregister(model: Model)
	self.entities[model] = nil
end

function CombatService:GetEntity(model: Model?): Entity?
	if not model then
		return nil
	end
	return self.entities[model]
end

--[[
	Walks up from a hit part to the registered entity that owns it. Returns the
	entity plus the hit region name and its multiplier, read from the shared
	contract attributes if the authored/generated part supplies them.
]]
function CombatService:ResolveHit(part: BasePart?): (Entity?, string?, number?)
	if not part then
		return nil, nil, nil
	end

	local regionName = part:GetAttribute("RegionId") :: string?
	local regionMultiplier = part:GetAttribute("DamageMultiplier") :: number?

	-- Roblox default rigs: treat the head as a crit region even when the
	-- Studio workstream has not tagged it yet.
	if not regionName and part.Name == "Head" then
		regionName = "Head"
	end

	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") and self.entities[current] then
			return self.entities[current], regionName, regionMultiplier
		end
		current = current.Parent
	end

	return nil, regionName, regionMultiplier
end

function CombatService:SetInvulnerable(model: Model, seconds: number)
	local entity = self.entities[model]
	if entity then
		entity.invulnerableUntil = math.max(entity.invulnerableUntil, os.clock() + seconds)
	end
end

--[[
	Whether `attacker` is permitted to damage `target`.

	Milestone 1 has no open-world PvP, so this is simple — but it is already the
	single gate the scaffold requires (§C12: "PvPService:CanDamage() as the
	single permission gate"). When zones and PvP land, this function grows; no
	call site changes.
]]
function CombatService:CanDamage(attacker: Entity?, target: Entity): boolean
	if target.dead then
		return false
	end
	if os.clock() < target.invulnerableUntil then
		return false
	end
	if not attacker then
		return true -- environmental damage
	end
	if attacker == target then
		return false
	end
	-- No friendly fire in the slice; players cannot damage players yet.
	if attacker.faction == target.faction then
		return false
	end
	return true
end

--[[
	Applies damage and replicates the result.

	Returns nil when the damage was not permitted, so callers can distinguish
	"blocked" from "dealt zero".
]]
function CombatService:ApplyDamage(
	targetModel: Model,
	context: DamageContext,
	modifiers: DamageCalculator.Modifiers?,
	attackerModel: Model?
): DamageResult?
	local target = self.entities[targetModel]
	if not target then
		return nil
	end

	local attacker = if attackerModel then self.entities[attackerModel] else nil
	if not self:CanDamage(attacker, target) then
		return nil
	end

	local isPvP = attacker ~= nil and attacker.faction == "Player" and target.faction == "Player"
	context.isPvP = isPvP

	local amount = DamageCalculator.compute(context, modifiers)
	amount *= 1 - math.clamp(target.damageReduction, 0, 0.95)
	amount = math.max(0, amount)

	target.health = math.max(0, target.health - amount)
	target.lastDamagedAt = os.clock()

	if target.humanoid then
		target.humanoid.Health = (target.health / target.maxHealth) * target.humanoid.MaxHealth
	end

	local result: DamageResult = {
		applied = amount,
		remainingHealth = target.health,
		killed = target.health <= 0,
		isCritical = context.isCritical,
		hitRegion = context.hitRegion,
	}

	self:_replicateDamage(target, attacker, context, result)
	self.Damaged:Fire(target, attacker, result, context)

	if result.killed and not target.dead then
		target.dead = true
		self.diedRemote:FireAllClients(target.entityId, target.model.Name)
		self.Died:Fire(target, attacker)
	end

	return result
end

function CombatService:Heal(targetModel: Model, amount: number)
	local target = self.entities[targetModel]
	if not target or target.dead then
		return
	end

	target.health = math.min(target.maxHealth, target.health + amount)
	if target.humanoid then
		target.humanoid.Health = (target.health / target.maxHealth) * target.humanoid.MaxHealth
	end
	self.healthChangedRemote:FireAllClients(target.entityId, target.health, target.maxHealth)
end

function CombatService:_replicateDamage(
	target: Entity,
	attacker: Entity?,
	context: DamageContext,
	result: DamageResult
)
	-- Floating damage numbers are the attacker's feedback, so they are sent
	-- only to the attacker. Broadcasting every number to every client is both
	-- a bandwidth cost and visual noise over a boss (§17.1, §16.3).
	if attacker and attacker.player then
		self.damageDealtRemote:FireClient(attacker.player, {
			position = context.hitPosition,
			amount = result.applied,
			isCritical = result.isCritical,
			hitRegion = result.hitRegion,
			killed = result.killed,
			targetId = target.entityId,
		})
	end

	-- The victim gets a directional indicator, not a number.
	if target.player then
		local sourcePosition = context.hitPosition
		if attacker then
			local root = attacker.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				sourcePosition = root.Position
			end
		end
		self.damageTakenRemote:FireClient(target.player, {
			amount = result.applied,
			sourcePosition = sourcePosition,
			health = target.health,
			maxHealth = target.maxHealth,
		})
	end

	-- Boss health is public: everyone needs the phase bar (§17.1).
	if target.faction == "Boss" then
		self.healthChangedRemote:FireAllClients(target.entityId, target.health, target.maxHealth)
	end
end

return CombatService
