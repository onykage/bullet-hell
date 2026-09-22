--!strict
--[[
	BossService.luau

	The Storm Engine encounter: state machine, attack selection, and
	server-authoritative hit evaluation for bullet patterns.

	The server owns state, timing, valid targets, health, phase changes, and the
	result (§7.2). What it does NOT do is replicate projectiles. It sends one
	compact spawn record per pattern — id, seed, timestamp, origin, target — and
	both sides expand it through Shared/Combat/ProjectilePattern. Hundreds of
	on-screen projectiles cost one remote call (§16.1).

	Hit evaluation runs on a fixed 20 Hz tick, independent of frame rate, so
	server load does not change how dangerous a pattern is.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Contract = require(Shared.Contract)
local Events = require(Shared.Network.Events)
local ProjectilePattern = require(Shared.Combat.ProjectilePattern)
local Signal = require(Shared.Utility.Signal)
local StormEngine = require(Shared.Config.Bosses.StormEngine)

local Graybox = require(script.Parent.Parent.World.Graybox)

local HIT_TICK = 1 / 20
local PLAYER_HIT_RADIUS = 2.0

local BossService = {}

type ActivePattern = {
	instanceId: number,
	definition: any,
	spawn: any,
	shots: { ProjectilePattern.Shot },
	-- Per-player per-shot consumption, so one projectile cannot tick a player
	-- every frame it overlaps them.
	consumed: { [Player]: { [number]: boolean } },
}

function BossService:Init(context)
	self.combat = context.services.CombatService
	self.world = context.services.WorldBuilderService

	self.phase = "Dormant"
	self.phaseStartedAt = 0
	self.encounterStartedAt = 0
	self.activePatterns = {} :: { [number]: ActivePattern }
	self.nextPatternId = 0
	self.attackCooldowns = {} :: { [string]: number }
	self.participants = {} :: { [Player]: boolean }
	self.conductors = {} :: { [Model]: { part: BasePart, alive: boolean } }
	self.accumulator = 0
	self.bossModel = nil :: Model?
	self.bossEntity = nil

	self.EncounterEnded = Signal.new()
end

function BossService:Start()
	self.stateRemote = Events.get("S2C_BossState")
	self.patternRemote = Events.get("S2C_PatternSpawn")
	self.cancelRemote = Events.get("S2C_PatternCancelled")

	self.runtime = self.world:GetContainer(Contract.Containers.Runtime)
	self.bossFolder = Graybox.folder("Boss", self.runtime)

	self.combat.Died:Connect(function(entity)
		if entity.model == self.bossModel then
			self:_setPhase("Defeated")
		elseif self.conductors[entity.model] then
			self:_onConductorDestroyed(entity.model)
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		self.accumulator += deltaTime
		while self.accumulator >= HIT_TICK do
			self.accumulator -= HIT_TICK
			self:_tick(HIT_TICK)
		end
	end)
end

function BossService:IsActive(): boolean
	return self.phase ~= "Dormant" and self.phase ~= "Reset"
end

--[[
	Starts the encounter for a set of players. Idempotent: a second call while
	an encounter is running is ignored rather than stacking two bosses.
]]
function BossService:StartEncounter(participants: { Player }): boolean
	if self:IsActive() then
		return false
	end

	table.clear(self.participants)
	for _, player in participants do
		self.participants[player] = true
	end

	self:_spawnBoss(#participants)
	self:_spawnConductors()

	self.encounterStartedAt = os.clock()
	self:_setPhase("Preparing")
	return true
end

function BossService:AbortEncounter(reason: string)
	if not self:IsActive() then
		return
	end
	warn(`[BossService] encounter aborted: {reason}`)
	self:_setPhase("Reset")
end

function BossService:_spawnBoss(partySize: number)
	local marker =
		self.world:FindMarker(Contract.Tags.BossMarker, StormEngine.ArenaId, Contract.Markers.BossSpawn)
	assert(marker, "[BossService] no BossSpawn marker found for the Storm Engine arena")

	local config = StormEngine.Graybox
	local model = Instance.new("Model")
	model.Name = "StormEngine"

	local core = Graybox.part({
		name = "HumanoidRootPart",
		size = Vector3.new(16, config.BossHeight, 16),
		cframe = marker.CFrame * CFrame.new(0, config.BossHeight * 0.5, 0),
		color = Color3.fromRGB(78, 64, 120),
		material = Enum.Material.Metal,
		collisionGroup = Contract.CollisionGroups.Enemy,
		parent = model,
	})

	-- An exposed weak point: rewarding accuracy is the point of the archetype.
	local weakPoint = Graybox.part({
		name = "Core",
		size = Vector3.new(7, 7, 7),
		cframe = marker.CFrame * CFrame.new(0, config.BossHeight * 0.78, 0),
		color = Color3.fromRGB(255, 176, 64),
		material = Enum.Material.Neon,
		canCollide = false,
		collisionGroup = Contract.CollisionGroups.Enemy,
		parent = model,
	})
	Graybox.mark(weakPoint, Contract.Tags.WeakPoint, "storm_engine_core", {
		RegionId = "WeakPoint",
		DamageMultiplier = Balance.HitRegions.WeakPoint,
	})

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = core
	weld.Part1 = weakPoint
	weld.Parent = core

	model.PrimaryPart = core
	model.Parent = self.bossFolder

	local maxHealth = StormEngine.Health.BasePerPlayer * math.max(1, partySize)

	self.bossModel = model
	self.bossEntity = self.combat:Register({
		model = model,
		faction = "Boss",
		maxHealth = maxHealth,
		entityId = "storm_engine",
	})

	-- Phase one is gated behind the conductors: full damage reduction until
	-- players break them.
	self.bossEntity.damageReduction = StormEngine.Conductors.Count
		* StormEngine.Conductors.DamageReductionPerConductor
end

function BossService:_spawnConductors()
	table.clear(self.conductors)

	for _, part in CollectionService:GetTagged(Contract.Tags.Conductor) do
		if part:GetAttribute("ArenaId") ~= StormEngine.ArenaId then
			continue
		end

		-- Conductors are authored geometry, so each gets a lightweight model
		-- wrapper to participate in the standard damage path.
		local wrapper = Instance.new("Model")
		wrapper.Name = part.Name
		wrapper.Parent = self.bossFolder

		local clone = (part :: BasePart):Clone()
		clone.Parent = wrapper
		clone.Transparency = 0
		wrapper.PrimaryPart = clone;
		(part :: BasePart).Transparency = 1
		(part :: BasePart).CanCollide = false

		self.combat:Register({
			model = wrapper,
			faction = "Boss",
			maxHealth = StormEngine.Conductors.Health,
			entityId = `conductor_{part.Name}`,
		})

		self.conductors[wrapper] = { part = part :: BasePart, alive = true }
	end
end

function BossService:_onConductorDestroyed(model: Model)
	local record = self.conductors[model]
	if not record or not record.alive then
		return
	end
	record.alive = false

	if self.bossEntity then
		self.bossEntity.damageReduction =
			math.max(0, self.bossEntity.damageReduction - StormEngine.Conductors.DamageReductionPerConductor)
	end

	model:Destroy()
	self.conductors[model] = nil
	self:_broadcastState()
end

function BossService:_setPhase(phase: string)
	self.phase = phase
	self.phaseStartedAt = os.clock()
	self:_broadcastState()

	if phase == "Defeated" then
		self:_clearPatterns()
		task.delay(StormEngine.PhaseTiming.DefeatedSeconds, function()
			if self.phase == "Defeated" then
				self:_setPhase("Rewards")
			end
		end)
	elseif phase == "Rewards" then
		task.delay(StormEngine.PhaseTiming.RewardsSeconds, function()
			if self.phase == "Rewards" then
				self.EncounterEnded:Fire(true)
				self:_setPhase("Reset")
			end
		end)
	elseif phase == "Reset" then
		self:_cleanup()
		task.delay(1, function()
			self.phase = "Dormant"
			self:_broadcastState()
		end)
	end
end

function BossService:_broadcastState()
	local conductorsAlive = 0
	for _, record in self.conductors do
		if record.alive then
			conductorsAlive += 1
		end
	end

	self.stateRemote:FireAllClients({
		phase = self.phase,
		health = if self.bossEntity then self.bossEntity.health else 0,
		maxHealth = if self.bossEntity then self.bossEntity.maxHealth else 0,
		conductorsAlive = conductorsAlive,
		conductorsTotal = StormEngine.Conductors.Count,
		damageReduction = if self.bossEntity then self.bossEntity.damageReduction else 0,
		displayName = StormEngine.DisplayName,
	})
end

function BossService:_tick()
	if not self:IsActive() then
		return
	end

	self:_stepPatterns()

	local elapsedInPhase = os.clock() - self.phaseStartedAt
	local timing = StormEngine.PhaseTiming

	if self.phase == "Preparing" then
		if elapsedInPhase >= timing.PreparingSeconds then
			self:_setPhase("Intro")
		end
		return
	end

	if self.phase == "Intro" then
		if elapsedInPhase >= timing.IntroSeconds then
			self:_setPhase("PhaseOne")
		end
		return
	end

	if self.phase == "Transition" then
		self:_selectAttack()
		if elapsedInPhase >= timing.TransitionSeconds then
			self:_setPhase("PhaseTwo")
		end
		return
	end

	if self.phase ~= "PhaseOne" and self.phase ~= "PhaseTwo" and self.phase ~= "Enraged" then
		return
	end

	if not self.bossEntity or self.bossEntity.dead then
		return
	end

	-- Wipe check: if nobody is alive in the arena, reset rather than leaving a
	-- half-run encounter blocking the entrance (§20.3).
	if not self:_anyParticipantAlive() then
		self.EncounterEnded:Fire(false)
		self:_setPhase("Reset")
		return
	end

	if
		self.phase == "PhaseOne"
		and self.bossEntity.health / self.bossEntity.maxHealth <= StormEngine.Health.PhaseTwoThreshold
	then
		self:_setPhase("Transition")
		return
	end

	if
		self.phase ~= "Enraged"
		and os.clock() - self.encounterStartedAt >= StormEngine.Health.EnrageAtSeconds
	then
		self:_setPhase("Enraged")
		return
	end

	self:_selectAttack()
end

function BossService:_anyParticipantAlive(): boolean
	for player in self.participants do
		if not player.Parent then
			continue
		end
		local entity = self.combat:GetEntity(player.Character)
		if entity and not entity.dead then
			return true
		end
	end
	return false
end

function BossService:_selectAttack()
	local now = os.clock()
	local candidates = {}
	local totalWeight = 0

	local cooldownScale = if self.phase == "Enraged"
		then StormEngine.PhaseTiming.EnrageCooldownMultiplier
		else 1

	for _, attack in StormEngine.Attacks do
		if not attack.Phases[self.phase] then
			continue
		end
		local readyAt = self.attackCooldowns[attack.Id] or 0
		if now < readyAt then
			continue
		end
		totalWeight += attack.Weight
		table.insert(candidates, attack)
	end

	if #candidates == 0 then
		return
	end

	local roll = math.random() * totalWeight
	local chosen = candidates[#candidates]
	for _, attack in candidates do
		roll -= attack.Weight
		if roll <= 0 then
			chosen = attack
			break
		end
	end

	self.attackCooldowns[chosen.Id] = now + chosen.Cooldown * cooldownScale
	self:_executeAttack(chosen)
end

function BossService:_executeAttack(attack: any)
	local definition = StormEngine.Patterns[attack.PatternId]
	assert(definition, `[BossService] attack {attack.Id} references unknown pattern {attack.PatternId}`)

	local origin = self:_originFor(attack)
	if not origin then
		return
	end

	local targetPosition: Vector3? = nil
	if attack.Targeting == "RandomPlayer" then
		local alive = {}
		for player in self.participants do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local entity = self.combat:GetEntity(character)
			if root and entity and not entity.dead then
				table.insert(alive, root.Position)
			end
		end
		if #alive == 0 then
			return
		end
		targetPosition = alive[math.random(1, #alive)]
	end

	-- Enrage speeds patterns up; it does not increase their damage (§19.3).
	local speedScale = if self.phase == "Enraged" then StormEngine.PhaseTiming.EnrageSpeedMultiplier else 1
	local scaled = table.clone(definition)
	scaled.Speed = definition.Speed * speedScale
	scaled.RotationSpeed = (definition.RotationSpeed or 0) * speedScale

	self.nextPatternId += 1
	local spawn = {
		patternId = definition.Id,
		instanceId = self.nextPatternId,
		seed = math.random(1, 2 ^ 31 - 1),
		startTime = Workspace:GetServerTimeNow(),
		origin = origin,
		targetPosition = targetPosition,
		damage = definition.Damage,
		damageType = definition.DamageType,
	}

	self.activePatterns[spawn.instanceId] = {
		instanceId = spawn.instanceId,
		definition = scaled,
		spawn = spawn,
		shots = ProjectilePattern.build(scaled, spawn),
		consumed = {},
	}

	-- One remote call carries a pattern that renders as hundreds of
	-- projectiles on every client.
	self.patternRemote:FireAllClients(spawn, speedScale)
end

function BossService:_originFor(attack: any): CFrame?
	if attack.Targeting == "Self" then
		local boss = self.bossModel
		local root = boss and boss.PrimaryPart
		return root and root.CFrame
	end

	local origins = self.world:FindMarkers(Contract.Tags.AttackOrigin, StormEngine.ArenaId)
	if #origins == 0 then
		local boss = self.bossModel
		local root = boss and boss.PrimaryPart
		return root and root.CFrame
	end

	return origins[math.random(1, #origins)].CFrame
end

function BossService:_stepPatterns()
	local now = Workspace:GetServerTimeNow()
	local liveProjectiles = 0

	for instanceId, pattern in self.activePatterns do
		local elapsed = now - pattern.spawn.startTime

		if ProjectilePattern.isFinished(pattern.shots, pattern.definition, elapsed) then
			self.activePatterns[instanceId] = nil
			continue
		end

		liveProjectiles += #pattern.shots

		for player in self.participants do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end

			local entity = self.combat:GetEntity(character)
			if not entity or entity.dead then
				continue
			end

			local consumed = pattern.consumed[player]
			if not consumed then
				consumed = {}
				pattern.consumed[player] = consumed
			end

			local hits = ProjectilePattern.overlapping(
				pattern.shots,
				pattern.definition,
				elapsed,
				root.Position,
				PLAYER_HIT_RADIUS,
				consumed
			)

			for _, shotIndex in hits do
				consumed[shotIndex] = true

				self.combat:ApplyDamage(character :: Model, {
					attackerUserId = nil,
					sourceId = `boss:{pattern.spawn.patternId}`,
					weaponId = nil,
					damageType = pattern.definition.DamageType,
					baseDamage = pattern.definition.Damage,
					hitPosition = root.Position,
					hitRegion = "Body",
					isCritical = false,
					isPvP = false,
					sequenceId = pattern.instanceId,
				}, nil, self.bossModel)
			end
		end
	end

	-- Budget guard (§16.4). Exceeding it means a tuning mistake, not a player
	-- action, so it is logged loudly rather than silently dropped.
	if liveProjectiles > Balance.Limits.MaxSimultaneousProjectiles then
		warn(`[BossService] projectile budget exceeded: {liveProjectiles}`)
	end
end

function BossService:_clearPatterns()
	for instanceId in self.activePatterns do
		self.cancelRemote:FireAllClients(instanceId)
	end
	table.clear(self.activePatterns)
end

function BossService:_cleanup()
	self:_clearPatterns()
	table.clear(self.attackCooldowns)

	if self.bossModel then
		self.combat:Unregister(self.bossModel)
		self.bossModel:Destroy()
		self.bossModel = nil
		self.bossEntity = nil
	end

	for model, record in self.conductors do
		record.part.Transparency = 0
		record.part.CanCollide = true
		self.combat:Unregister(model)
		if model.Parent then
			model:Destroy()
		end
	end
	table.clear(self.conductors)
	table.clear(self.participants)
end

return BossService
