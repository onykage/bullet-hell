--!strict
--[[
	WorldBuilderService.luau

	Builds the milestone-1 blockout: a safe hub, a firing range, an arena
	entrance landmark, and the Storm Engine arena.

	It runs ONLY when the required containers are empty. The moment the Studio
	workstream commits authored geometry with the same tags, this service finds
	the containers populated and does nothing — no flag flip, no code change.
	Set the `GrayboxDisabled` attribute on Workspace to force it off.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local StormEngine = require(Shared.Config.Bosses.StormEngine)

local Graybox = require(script.Parent.Parent.World.Graybox)

local HUB_CENTER = Vector3.new(0, 0, 0)
local ARENA_CENTER = Vector3.new(0, 0, 700)
local RANGE_CENTER = Vector3.new(0, 0, -170)

--[[
	The world is built on ONE continuous collision surface.

	Every visible floor is a decorative, non-collidable, non-queryable skin laid
	flush on top of this slab. Nothing else in the world is walkable. That is a
	deliberate response to players falling out of the map: the previous layout
	used a separate collidable slab per area, and the seams and voids between
	them were somewhere to fall. With one slab there is no seam to find.

	Bedrock's top face is exactly y = 0, so every surface, spawn, and marker can
	be positioned against a known ground plane.
]]
local BEDROCK_SIZE = Vector3.new(460, 24, 1240)
local BEDROCK_CENTER = Vector3.new(0, -12, 235)
local BEDROCK_HALF_X = BEDROCK_SIZE.X * 0.5
local BEDROCK_MIN_Z = BEDROCK_CENTER.Z - BEDROCK_SIZE.Z * 0.5
local BEDROCK_MAX_Z = BEDROCK_CENTER.Z + BEDROCK_SIZE.Z * 0.5

local HUB_RADIUS = 112
local PERIMETER_HEIGHT = 260

-- Below this the player is falling out of the world and is recovered rather
-- than killed. It sits well above FallenPartsDestroyHeight so recovery always
-- wins the race against destruction.
local VOID_Y = -90
local VOID_CHECK_INTERVAL = 0.4

local COLORS = {
	bedrock = Color3.fromRGB(38, 40, 48),
	hubFloor = Color3.fromRGB(78, 84, 96),
	rangeFloor = Color3.fromRGB(66, 72, 82),
	arenaFloor = Color3.fromRGB(54, 56, 66),
	wall = Color3.fromRGB(46, 48, 58),
	cover = Color3.fromRGB(88, 92, 104),
	safe = Color3.fromRGB(96, 220, 160),
	contested = Color3.fromRGB(240, 120, 96),
	arenaPad = Color3.fromRGB(150, 130, 255),
}

local WorldBuilderService = {}
WorldBuilderService.arenaCenter = ARENA_CENTER
WorldBuilderService.hubCenter = HUB_CENTER

function WorldBuilderService:Init()
	self.containers = {}

	for _, name in Contract.Containers do
		self.containers[name] = Graybox.folder(name, Workspace)
	end

	self.runtime = self.containers[Contract.Containers.Runtime]
	self.voidAccumulator = 0
end

function WorldBuilderService:Start()
	--[[
		The world is built BEFORE anything else, and everything else is
		guarded.

		This service previously started its void-recovery watcher first. That
		watcher's first line wrote Workspace.FallenPartsDestroyHeight, which
		ordinary scripts are not allowed to do; it threw, Start never reached
		the geometry, and the entire world silently did not exist. A safety net
		must never be able to stop the thing it protects.
	]]
	self:_buildWorld()

	-- Recovery runs whether or not the graybox generated, because falling out
	-- of authored geometry is just as possible.
	local ok, err = pcall(function()
		self:_startVoidRecovery()
	end)
	if not ok then
		warn(`[WorldBuilder] void recovery unavailable: {err}`)
	end
end

function WorldBuilderService:_buildWorld()
	if Workspace:GetAttribute("GrayboxDisabled") == true then
		print("[WorldBuilder] graybox disabled by Workspace attribute; using authored geometry")
		return
	end

	local world = self.containers[Contract.Containers.World]
	if #world:GetChildren() > 0 then
		print("[WorldBuilder] authored geometry present; skipping graybox generation")
		return
	end

	self:_buildBedrock()
	self:_buildHub()
	self:_buildFiringRange()
	self:_buildArena()
	self:_buildZones()

	print("[WorldBuilder] graybox generated")
end

function WorldBuilderService:GetContainer(name: string): Folder
	local container = self.containers[name]
	assert(container, `[WorldBuilder] unknown container {name}`)
	return container
end

--[[
	Finds a tagged marker by its MarkerId attribute. Services must use this
	rather than a path, so authored and generated content are interchangeable.
]]
function WorldBuilderService:FindMarker(tag: string, arenaId: string, markerId: string): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:GetAttribute("ArenaId") == arenaId and instance:GetAttribute("MarkerId") == markerId then
			return instance :: BasePart
		end
	end
	return nil
end

function WorldBuilderService:FindMarkers(tag: string, arenaId: string): { BasePart }
	local found = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:GetAttribute("ArenaId") == arenaId then
			table.insert(found, instance)
		end
	end
	return found
end

--[[
	The single walkable surface, plus an invisible perimeter so its edge is not
	itself a place to fall off.
]]
function WorldBuilderService:_buildBedrock()
	local world = self.containers[Contract.Containers.World]
	local ground = Graybox.folder("Ground", world)

	Graybox.part({
		name = "Bedrock",
		size = BEDROCK_SIZE,
		cframe = CFrame.new(BEDROCK_CENTER),
		color = COLORS.bedrock,
		material = Enum.Material.Slate,
		parent = ground,
	})

	local length = BEDROCK_SIZE.Z
	local width = BEDROCK_SIZE.X
	local height = PERIMETER_HEIGHT
	local centerZ = BEDROCK_CENTER.Z

	local edges = {
		{ Vector3.new(width, height, 8), CFrame.new(0, height * 0.5, BEDROCK_MIN_Z) },
		{ Vector3.new(width, height, 8), CFrame.new(0, height * 0.5, BEDROCK_MAX_Z) },
		{ Vector3.new(8, height, length), CFrame.new(-BEDROCK_HALF_X, height * 0.5, centerZ) },
		{ Vector3.new(8, height, length), CFrame.new(BEDROCK_HALF_X, height * 0.5, centerZ) },
	}

	for index, edge in edges do
		Graybox.barrier(`PerimeterBarrier{index}`, edge[1], edge[2], ground)
	end
end

function WorldBuilderService:_buildHub()
	local world = self.containers[Contract.Containers.World]
	local hub = Graybox.folder("Hub", world)

	-- Decorative only. Bedrock is what the player stands on.
	Graybox.surface(
		"HubFloor",
		Vector3.new(HUB_RADIUS * 2.4, 0.4, HUB_RADIUS * 2.4),
		CFrame.new(HUB_CENTER + Vector3.new(0, 0.2, 0)),
		COLORS.hubFloor,
		Enum.Material.Concrete,
		hub
	)

	-- A sealed ring with a doorway toward the arena, so the hub reads as a
	-- place you leave rather than a box. The gap is part of the ring's own
	-- definition, and bedrock continues underneath it, so it is a doorway and
	-- not a hole. +Z is 90 degrees in the ring's angle space.
	Graybox.sealedRing({
		center = HUB_CENTER,
		radius = HUB_RADIUS,
		height = 18,
		thickness = 6,
		segments = 20,
		color = COLORS.wall,
		material = Enum.Material.Concrete,
		name = "HubWall",
		parent = hub,
		gapCenter = 90,
		gapWidth = 34,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 0.5, 0))
	spawn.Anchored = true
	spawn.Color = COLORS.safe
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Parent = hub
	-- Keep Position in step with CFrame; see Graybox.place.
	spawn.Position = spawn.CFrame.Position
	Graybox.mark(spawn, Contract.Tags.PlayerSpawn, "hub_spawn_main", {
		SpawnId = "hub_main",
		SpawnType = "Sanctuary",
	})
	Graybox.label("HUB — Sanctuary (no PvP)", spawn, 6, COLORS.safe)

	self.hubSpawn = spawn

	-- Wall-run practice: two parallel slabs inside the hub, close enough to
	-- chain between. Teaching a movement mechanic in the safe zone beats
	-- discovering it mid-boss.
	for index, offsetX in { -14, 14 } do
		Graybox.part({
			name = `WallRunFace{index}`,
			size = Vector3.new(4, 26, 70),
			cframe = CFrame.new(HUB_CENTER + Vector3.new(offsetX, 13, -60)),
			color = Color3.fromRGB(96, 104, 126),
			material = Enum.Material.Brick,
			parent = hub,
		})
	end

	local sign = Graybox.part({
		name = "WallRunSign",
		size = Vector3.new(8, 1, 8),
		cframe = CFrame.new(HUB_CENTER + Vector3.new(0, 0.3, -60)),
		color = Color3.fromRGB(120, 130, 160),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = hub,
	})
	sign.CanQuery = false
	Graybox.label("WALL RUN — sprint, jump, hold into a wall", sign, 5, Color3.fromRGB(150, 200, 255))

	-- Arena entrance landmark. Arenas are physical places in the world (§4.3).
	local entrance = Graybox.pad(
		"StormEngineEntrance",
		12,
		CFrame.new(HUB_CENTER + Vector3.new(0, 0.3, 84)),
		COLORS.arenaPad,
		hub
	)
	Graybox.mark(entrance, Contract.Tags.ArenaEntrance, "entrance_storm_engine", {
		ArenaId = StormEngine.ArenaId,
	})
	Graybox.label("THE STORM ENGINE — step on to begin", entrance, 10, COLORS.arenaPad)

	-- A visible tower behind the entrance: the dominant landmark (§4.2).
	Graybox.part({
		name = "StormEngineSpire",
		size = Vector3.new(26, 180, 26),
		cframe = CFrame.new(HUB_CENTER + Vector3.new(0, 90, 220)),
		color = Color3.fromRGB(64, 58, 88),
		material = Enum.Material.Slate,
		parent = world,
	})

	self.arenaEntrance = entrance
end

function WorldBuilderService:_buildFiringRange()
	local world = self.containers[Contract.Containers.World]
	local range = Graybox.folder("FiringRange", world)

	Graybox.surface(
		"RangeFloor",
		Vector3.new(150, 0.4, 300),
		CFrame.new(RANGE_CENTER + Vector3.new(0, 0.2, 0)),
		COLORS.rangeFloor,
		Enum.Material.Concrete,
		range
	)

	-- Distance markers: the range exists to make falloff legible, so the
	-- distances are the content.
	for _, distance in { 25, 50, 100, 180, 260 } do
		local stripe = Graybox.surface(
			`Marker{distance}`,
			Vector3.new(150, 0.4, 1.5),
			CFrame.new(RANGE_CENTER + Vector3.new(0, 0.35, -distance + 140)),
			Color3.fromRGB(200, 200, 210),
			Enum.Material.Neon,
			range
		)
		Graybox.label(`{distance} studs`, stripe, 3, Color3.fromRGB(190, 195, 205))
	end

	-- Dummy spawn volume, read by EnemyService via the contract.
	local volume = Graybox.volume(
		"DummyVolume",
		Vector3.new(70, 20, 30),
		CFrame.new(RANGE_CENTER + Vector3.new(0, 10, -120)),
		self.containers[Contract.Containers.SpawnVolumes]
	)
	Graybox.mark(volume, Contract.Tags.EnemySpawnVolume, "range_dummies", {
		EncounterId = "firing_range",
		SpawnGroup = "target_dummy",
	})

	local grunts = Graybox.volume(
		"GruntVolume",
		Vector3.new(70, 20, 60),
		CFrame.new(RANGE_CENTER + Vector3.new(0, 10, -50)),
		self.containers[Contract.Containers.SpawnVolumes]
	)
	Graybox.mark(grunts, Contract.Tags.EnemySpawnVolume, "range_grunts", {
		EncounterId = "firing_range",
		SpawnGroup = "mixed",
	})
end

function WorldBuilderService:_buildArena()
	local world = self.containers[Contract.Containers.World]
	local arena = Graybox.folder("StormEngineArena", world)
	local config = StormEngine.Graybox
	local markers = self.containers[Contract.Containers.EncounterMarkers]

	Graybox.surface(
		"ArenaFloor",
		Vector3.new(config.ArenaRadius * 2.3, 0.4, config.ArenaRadius * 2.3),
		CFrame.new(ARENA_CENTER + Vector3.new(0, 0.2, 0)),
		COLORS.arenaFloor,
		-- Flat and low-noise so telegraphs read clearly against it (§R9).
		Enum.Material.Pebble,
		arena
	)

	-- Boundary wall, sealed by construction.
	Graybox.sealedRing({
		center = ARENA_CENTER,
		radius = config.ArenaRadius,
		height = config.WallHeight,
		thickness = 6,
		segments = 28,
		color = COLORS.wall,
		material = Enum.Material.Metal,
		name = "ArenaWall",
		parent = arena,
	})

	-- An invisible cap. Wall running plus a wall jump adds real height, and an
	-- open-topped arena is an invitation to leave the fight from above.
	Graybox.barrier(
		"ArenaCeiling",
		Vector3.new(config.ArenaRadius * 2.6, 4, config.ArenaRadius * 2.6),
		CFrame.new(ARENA_CENTER + Vector3.new(0, config.CeilingHeight, 0)),
		arena
	)

	-- Cover that blocks line of sight for the targeted-line attack but not the
	-- radial waves, so the two attacks demand different answers. Tall enough to
	-- wall run along, which gives the movement kit a use inside the fight.
	for _, frame in Graybox.ring(ARENA_CENTER, config.CoverPillarRadius, config.CoverPillarCount, 30) do
		Graybox.part({
			name = "CoverPillar",
			size = Vector3.new(7, 20, 14),
			cframe = frame * CFrame.new(0, 10, 0),
			color = COLORS.cover,
			material = Enum.Material.Metal,
			parent = arena,
		})
	end

	local bossSpawn = Graybox.part({
		name = "BossSpawn",
		size = Vector3.new(10, 1, 10),
		cframe = CFrame.new(ARENA_CENTER + Vector3.new(0, 0.5, 0)),
		color = Color3.fromRGB(120, 90, 200),
		material = Enum.Material.Neon,
		canCollide = false,
		parent = markers,
	})
	Graybox.mark(bossSpawn, Contract.Tags.BossMarker, "storm_boss_spawn", {
		ArenaId = StormEngine.ArenaId,
		MarkerId = Contract.Markers.BossSpawn,
	})

	-- Attack origins: the points patterns are emitted from (§7.3 "required
	-- arena markers"). BossService reads these by tag, never by path.
	for index, frame in Graybox.ring(ARENA_CENTER, config.AttackOriginRadius, config.AttackOriginCount) do
		local origin = Graybox.part({
			name = `AttackOrigin{index}`,
			size = Vector3.new(2, 2, 2),
			cframe = frame * CFrame.new(0, 8, 0),
			color = Color3.fromRGB(255, 150, 80),
			material = Enum.Material.Neon,
			canCollide = false,
			transparency = 0.5,
			parent = markers,
		})
		Graybox.mark(origin, Contract.Tags.AttackOrigin, `storm_attack_origin_{index}`, {
			ArenaId = StormEngine.ArenaId,
			MarkerId = `AttackOrigin{index}`,
		})
	end

	-- Conductors: the phase-one damage window mechanic.
	for index, frame in Graybox.ring(ARENA_CENTER, config.ConductorRadius, StormEngine.Conductors.Count, 45) do
		local conductor = Graybox.part({
			name = `Conductor{index}`,
			size = Vector3.new(5, 14, 5),
			cframe = frame * CFrame.new(0, 7, 0),
			color = Color3.fromRGB(120, 210, 255),
			material = Enum.Material.Neon,
			parent = markers,
		})
		Graybox.mark(conductor, Contract.Tags.Conductor, `storm_conductor_{index}`, {
			ArenaId = StormEngine.ArenaId,
			MarkerId = `Conductor{index}`,
		})
		Graybox.label(`CONDUCTOR {index}`, conductor, 10, Color3.fromRGB(120, 210, 255))
	end

	-- Player spawns inside the arena.
	for index, frame in Graybox.ring(ARENA_CENTER, config.PlayerSpawnRadius, config.PlayerSpawnCount, 90) do
		local pad = Graybox.pad(`ArenaSpawn{index}`, 5, frame * CFrame.new(0, 0.3, 0), COLORS.safe, markers)
		Graybox.mark(pad, Contract.Tags.PlayerSpawn, `storm_arena_spawn_{index}`, {
			SpawnId = `storm_arena_{index}`,
			SpawnType = "Arena",
		})
	end
end

function WorldBuilderService:_buildZones()
	local zones = self.containers[Contract.Containers.ZoneVolumes]

	local sanctuary = Graybox.volume(
		"HubSanctuary",
		Vector3.new(250, 160, 250),
		CFrame.new(HUB_CENTER + Vector3.new(0, 75, 0)),
		zones
	)
	Graybox.mark(sanctuary, Contract.Tags.Zone, "zone_hub", { ZoneId = "hub_sanctuary" })

	local rangeZone = Graybox.volume(
		"RangeZone",
		Vector3.new(160, 160, 310),
		CFrame.new(RANGE_CENTER + Vector3.new(0, 75, 0)),
		zones
	)
	Graybox.mark(rangeZone, Contract.Tags.Zone, "zone_range", { ZoneId = "firing_range" })

	local arenaZone = Graybox.volume(
		"StormArenaZone",
		Vector3.new(220, 180, 220),
		CFrame.new(ARENA_CENTER + Vector3.new(0, 80, 0)),
		zones
	)
	Graybox.mark(arenaZone, Contract.Tags.Zone, "zone_storm_arena", { ZoneId = "storm_engine_arena" })
end

--[[
	Falling out of the world returns the player to safety instead of killing
	them.

	Death-on-fall is a punishment for a level-geometry bug, which is the wrong
	party to punish. It also hides the bug: a player who dies assumes they made
	a mistake, while a player who is visibly rescued reports it.
]]
function WorldBuilderService:_startVoidRecovery()
	-- FallenPartsDestroyHeight is NOT set here. It is a place property that
	-- ordinary scripts are not permitted to write — the attempt throws
	-- "lacking capability plugin" — so it lives in default.project.json, set
	-- to -500 so recovery at VOID_Y always wins the race.
	RunService.Heartbeat:Connect(function(deltaTime)
		self.voidAccumulator += deltaTime
		if self.voidAccumulator < VOID_CHECK_INTERVAL then
			return
		end
		self.voidAccumulator = 0

		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or root.Position.Y > VOID_Y then
				continue
			end

			local destination = self:_recoveryPoint(root.Position)
			if not destination then
				continue
			end

			warn(`[WorldBuilder] recovered {player.Name} from the void at {root.Position}`);
			(character :: Model):PivotTo(CFrame.new(destination + Vector3.new(0, 6, 0)))
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end)
end

--[[
	Nearest sensible place to put a recovered player: an arena spawn if they
	fell inside the arena footprint, otherwise the hub.
]]
function WorldBuilderService:_recoveryPoint(fellFrom: Vector3): Vector3?
	local insideArena = (Vector3.new(fellFrom.X, 0, fellFrom.Z) - Vector3.new(
		ARENA_CENTER.X,
		0,
		ARENA_CENTER.Z
	)).Magnitude < StormEngine.Graybox.ArenaRadius * 1.5

	local wantedType = if insideArena then "Arena" else "Sanctuary"

	for _, instance in CollectionService:GetTagged(Contract.Tags.PlayerSpawn) do
		if instance:IsA("BasePart") and instance:GetAttribute("SpawnType") == wantedType then
			return instance.Position
		end
	end

	local hubSpawn = self.hubSpawn
	return if hubSpawn then hubSpawn.Position else HUB_CENTER
end

return WorldBuilderService
