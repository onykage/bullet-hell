--!strict
--[[
	EnemyService.luau

	Spawns and runs the milestone-1 enemies from tagged spawn volumes.

	Deliberate simplification: these are anchored, server-stepped primitives,
	not Humanoid rigs with pathfinding. The scaffold puts enemy rigs, animations
	and navigation-ready geometry on the Studio workstream (§R8, §R11), and
	building throwaway Humanoid rigs here would produce physics bugs that teach
	us nothing about the combat we are actually trying to prove. Movement is a
	direct CFrame step with a ground raycast; when real rigs land, only
	`_stepEnemy` changes.

	AI update rate is decoupled from frame rate and scaled by distance (§16.2).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Contract = require(Shared.Contract)
local EnemyConfig = require(Shared.Config.Enemies)

local Graybox = require(script.Parent.Parent.World.Graybox)

local AI_TICK = 0.1
local FAR_DISTANCE = 220 -- beyond this, decisions run at a quarter rate

local EnemyService = {}

type Enemy = {
	id: string,
	config: any,
	model: Model,
	root: BasePart,
	spawnPosition: Vector3,
	lastAttackAt: number,
	nextThinkAt: number,
	target: Player?,
}

function EnemyService:Init(context)
	self.combat = context.services.CombatService
	self.world = context.services.WorldBuilderService
	self.enemies = {} :: { [Model]: Enemy }
	self.accumulator = 0
	-- Entity ids come from a counter, not Instance:GetDebugId. GetDebugId
	-- requires plugin capability and throws when a game script calls it.
	self.nextEnemyNumber = 0
end

function EnemyService:Start()
	self.runtime = self.world:GetContainer(Contract.Containers.Runtime)
	self.enemyFolder = Graybox.folder("Enemies", self.runtime)

	self:_spawnFromVolumes()

	-- Dead enemies are cleared here rather than in CombatService, so combat
	-- stays free of entity-lifecycle concerns.
	self.combat.Died:Connect(function(entity)
		local enemy = self.enemies[entity.model]
		if enemy then
			self:_onEnemyDied(enemy)
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		self.accumulator += deltaTime
		if self.accumulator < AI_TICK then
			return
		end
		local step = self.accumulator
		self.accumulator = 0
		self:_step(step)
	end)
end

function EnemyService:_spawnFromVolumes()
	for _, volume in CollectionService:GetTagged(Contract.Tags.EnemySpawnVolume) do
		if not volume:IsA("BasePart") then
			continue
		end

		local group = volume:GetAttribute("SpawnGroup") :: string?
		if group == "target_dummy" then
			for index = 1, 5 do
				local offset = Vector3.new((index - 3) * 14, 0, 0)
				self:Spawn("target_dummy", volume.Position + offset - Vector3.new(0, volume.Size.Y * 0.5, 0))
			end
		elseif group == "mixed" then
			local layout = { "frontier_grunt", "frontier_grunt", "scrap_rusher", "arc_marksman" }
			for index, enemyId in layout do
				local offset = Vector3.new((index - 2.5) * 16, 0, 0)
				self:Spawn(enemyId, volume.Position + offset - Vector3.new(0, volume.Size.Y * 0.5, 0))
			end
		end
	end
end

function EnemyService:Spawn(enemyId: string, position: Vector3): Model
	local config = EnemyConfig.expect(enemyId)
	self.nextEnemyNumber += 1

	local model = Instance.new("Model")
	model.Name = config.DisplayName

	local root = Graybox.part({
		name = "HumanoidRootPart",
		size = config.Size,
		cframe = CFrame.new(position + Vector3.new(0, config.Size.Y * 0.5, 0)),
		color = config.Color,
		material = Enum.Material.Metal,
		canCollide = true,
		collisionGroup = Contract.CollisionGroups.Enemy,
		parent = model,
	})

	-- A distinct head, tagged as a crit region through the shared contract so
	-- the damage path reads it exactly as it will read authored rig geometry.
	local head = Graybox.part({
		name = "Head",
		size = Vector3.new(config.Size.X * 0.6, config.Size.X * 0.6, config.Size.X * 0.6),
		cframe = CFrame.new(position + Vector3.new(0, config.Size.Y + config.Size.X * 0.3, 0)),
		color = config.Color:Lerp(Color3.new(1, 1, 1), 0.35),
		material = Enum.Material.Metal,
		canCollide = false,
		collisionGroup = Contract.CollisionGroups.Enemy,
		parent = model,
	})
	Graybox.mark(head, Contract.Tags.HitRegion, `{enemyId}_head`, {
		RegionId = "Head",
		DamageMultiplier = Balance.HitRegions.Head,
	})

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	model.PrimaryPart = root
	model.Parent = self.enemyFolder

	self.combat:Register({
		model = model,
		faction = "Enemy",
		maxHealth = config.Health,
		entityId = `{enemyId}_{self.nextEnemyNumber}`,
		resetHealthAfter = config.ResetHealthAfter,
	})

	self.enemies[model] = {
		id = enemyId,
		config = config,
		model = model,
		root = root,
		spawnPosition = position,
		lastAttackAt = 0,
		nextThinkAt = 0,
		target = nil,
	}

	if config.Role == "Dummy" then
		Graybox.label(config.DisplayName, root, config.Size.Y * 0.5 + 4, Color3.fromRGB(220, 200, 140))
	end

	return model
end

function EnemyService:_nearestPlayer(position: Vector3, maxDistance: number): (Player?, number)
	local best: Player? = nil
	local bestDistance = maxDistance

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local entity = self.combat:GetEntity(character)
		if not entity or entity.dead then
			continue
		end

		local distance = (root.Position - position).Magnitude
		if distance < bestDistance then
			best = player
			bestDistance = distance
		end
	end

	return best, bestDistance
end

function EnemyService:_step(deltaTime: number)
	local now = os.clock()

	for model, enemy in self.enemies do
		if not model.Parent then
			self.enemies[model] = nil
			continue
		end

		local entity = self.combat:GetEntity(model)
		if not entity then
			continue
		end

		-- Dummies exist to be measured against; they heal back so a player can
		-- read the same DPS window repeatedly.
		if enemy.config.Role == "Dummy" then
			if entity.resetHealthAfter and entity.health < entity.maxHealth then
				if now - entity.lastDamagedAt > entity.resetHealthAfter then
					entity.health = entity.maxHealth
				end
			end
			continue
		end

		if entity.dead or now < enemy.nextThinkAt then
			continue
		end

		local target, distance = self:_nearestPlayer(enemy.root.Position, enemy.config.AttackRange * 2.5)
		enemy.target = target

		-- Distant enemies think less often (§16.2).
		enemy.nextThinkAt = now + (if distance > FAR_DISTANCE then AI_TICK * 4 else AI_TICK)

		if not target then
			continue
		end

		self:_stepEnemy(enemy, target, distance, deltaTime, now)
	end
end

function EnemyService:_stepEnemy(
	enemy: Enemy,
	target: Player,
	distance: number,
	deltaTime: number,
	now: number
)
	local character = target.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	local config = enemy.config
	local position = enemy.root.Position

	-- Close to preferred range, then hold. Marksmen keep their distance, which
	-- is what makes them punish standing still (§5.3).
	local preferred = if config.Role == "Marksman" then config.AttackRange * 0.7 else config.AttackRange * 0.5
	local toTarget = (targetRoot.Position - position) * Vector3.new(1, 0, 1)

	if toTarget.Magnitude > 0.5 and math.abs(toTarget.Magnitude - preferred) > 4 then
		local direction = toTarget.Unit
		if toTarget.Magnitude < preferred then
			direction = -direction
		end

		local nextPosition = position + direction * config.WalkSpeed * deltaTime

		-- Snap to ground so enemies follow slopes instead of hovering.
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { self.runtime }
		local ground =
			Workspace:Raycast(nextPosition + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), rayParams)
		if ground then
			nextPosition =
				Vector3.new(nextPosition.X, ground.Position.Y + config.Size.Y * 0.5, nextPosition.Z)
		end

		enemy.root.CFrame = CFrame.lookAt(
			nextPosition,
			Vector3.new(targetRoot.Position.X, nextPosition.Y, targetRoot.Position.Z)
		)
	else
		enemy.root.CFrame =
			CFrame.lookAt(position, Vector3.new(targetRoot.Position.X, position.Y, targetRoot.Position.Z))
	end

	if distance > config.AttackRange or now - enemy.lastAttackAt < config.AttackCooldown then
		return
	end

	-- Line of sight is required, so cover works against enemies too.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { enemy.model, self.runtime }
	local hit = Workspace:Raycast(position, targetRoot.Position - position, rayParams)
	if hit and not hit.Instance:IsDescendantOf(character :: Instance) then
		return
	end

	enemy.lastAttackAt = now

	self.combat:ApplyDamage(character :: Model, {
		attackerUserId = nil,
		sourceId = `enemy:{enemy.id}`,
		weaponId = nil,
		damageType = "Kinetic",
		baseDamage = config.Damage,
		hitPosition = targetRoot.Position,
		hitRegion = "Body",
		isCritical = false,
		isPvP = false,
		sequenceId = 0,
	}, nil, enemy.model)
end

function EnemyService:_onEnemyDied(enemy: Enemy)
	self.enemies[enemy.model] = nil
	self.combat:Unregister(enemy.model)

	-- Brief corpse, then cleanup. Respawn belongs to encounter logic, not here.
	task.delay(2.5, function()
		if enemy.model.Parent then
			enemy.model:Destroy()
		end
	end)

	task.delay(12, function()
		if enemy.config.Role ~= "Dummy" then
			self:Spawn(enemy.id, enemy.spawnPosition)
		end
	end)
end

function EnemyService:ClearAll()
	for model in self.enemies do
		self.combat:Unregister(model)
		model:Destroy()
	end
	table.clear(self.enemies)
end

return EnemyService
