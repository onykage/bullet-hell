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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local StormEngine = require(Shared.Config.Bosses.StormEngine)

local Graybox = require(script.Parent.Parent.World.Graybox)

local HUB_CENTER = Vector3.new(0, 0, 0)
local ARENA_CENTER = Vector3.new(0, 0, 700)
local RANGE_CENTER = Vector3.new(0, 0, -150)

local COLORS = {
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
end

function WorldBuilderService:Start()
	if Workspace:GetAttribute("GrayboxDisabled") == true then
		print("[WorldBuilder] graybox disabled by Workspace attribute; using authored geometry")
		return
	end

	local world = self.containers[Contract.Containers.World]
	if #world:GetChildren() > 0 then
		print("[WorldBuilder] authored geometry present; skipping graybox generation")
		return
	end

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

function WorldBuilderService:_buildHub()
	local world = self.containers[Contract.Containers.World]
	local hub = Graybox.folder("Hub", world)

	Graybox.part({
		name = "HubFloor",
		size = Vector3.new(220, 4, 220),
		cframe = CFrame.new(HUB_CENTER - Vector3.new(0, 2, 0)),
		color = COLORS.hubFloor,
		material = Enum.Material.Concrete,
		parent = hub,
	})

	-- A low wall so new players read the hub as enclosed and safe.
	for _, frame in Graybox.ring(HUB_CENTER, 112, 4, 45) do
		Graybox.part({
			name = "HubWall",
			size = Vector3.new(170, 14, 6),
			cframe = frame * CFrame.new(0, 7, 0),
			color = COLORS.wall,
			material = Enum.Material.Concrete,
			parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.CFrame = CFrame.new(HUB_CENTER + Vector3.new(0, 0.5, 0))
	spawn.Anchored = true
	spawn.Color = COLORS.safe
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Parent = hub
	Graybox.mark(spawn, Contract.Tags.PlayerSpawn, "hub_spawn_main", {
		SpawnId = "hub_main",
		SpawnType = "Sanctuary",
	})
	Graybox.label("HUB — Sanctuary (no PvP)", spawn, 6, COLORS.safe)

	self.hubSpawn = spawn

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
		cframe = CFrame.new(HUB_CENTER + Vector3.new(0, 90, 150)),
		color = Color3.fromRGB(64, 58, 88),
		material = Enum.Material.Slate,
		parent = hub,
	})

	self.arenaEntrance = entrance
end

function WorldBuilderService:_buildFiringRange()
	local world = self.containers[Contract.Containers.World]
	local range = Graybox.folder("FiringRange", world)

	Graybox.part({
		name = "RangeFloor",
		size = Vector3.new(90, 4, 280),
		cframe = CFrame.new(RANGE_CENTER - Vector3.new(0, 2, 0)),
		color = COLORS.rangeFloor,
		material = Enum.Material.Concrete,
		parent = range,
	})

	-- Distance markers: the range exists to make falloff legible, so the
	-- distances are the content.
	for _, distance in { 25, 50, 100, 180, 260 } do
		local stripe = Graybox.part({
			name = `Marker{distance}`,
			size = Vector3.new(90, 0.3, 1.5),
			cframe = CFrame.new(RANGE_CENTER + Vector3.new(0, 0.2, -distance + 130)),
			color = Color3.fromRGB(200, 200, 210),
			material = Enum.Material.Neon,
			canCollide = false,
			parent = range,
		})
		Graybox.label(`{distance} studs`, stripe, 3, Color3.fromRGB(190, 195, 205))
	end

	-- Dummy spawn volume, read by EnemyService via the contract.
	local volume = Graybox.volume(
		"DummyVolume",
		Vector3.new(70, 20, 30),
		CFrame.new(RANGE_CENTER + Vector3.new(0, 10, -110)),
		self.containers[Contract.Containers.SpawnVolumes]
	)
	Graybox.mark(volume, Contract.Tags.EnemySpawnVolume, "range_dummies", {
		EncounterId = "firing_range",
		SpawnGroup = "target_dummy",
	})

	local grunts = Graybox.volume(
		"GruntVolume",
		Vector3.new(70, 20, 60),
		CFrame.new(RANGE_CENTER + Vector3.new(0, 10, -40)),
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

	Graybox.part({
		name = "ArenaFloor",
		size = Vector3.new(config.ArenaRadius * 2.2, 4, config.ArenaRadius * 2.2),
		cframe = CFrame.new(ARENA_CENTER - Vector3.new(0, 2, 0)),
		color = COLORS.arenaFloor,
		-- A flat, low-noise floor so telegraphs read clearly against it (§R9).
		material = Enum.Material.Pebble,
		parent = arena,
	})

	-- Boundary wall: players must not be able to leave or climb out (§R9).
	for _, frame in Graybox.ring(ARENA_CENTER, config.ArenaRadius, 24) do
		Graybox.part({
			name = "ArenaWall",
			size = Vector3.new(22, config.WallHeight, 6),
			cframe = frame * CFrame.new(0, config.WallHeight * 0.5, 0),
			color = COLORS.wall,
			material = Enum.Material.Metal,
			parent = arena,
		})
	end

	-- Cover that blocks line of sight for the targeted-line attack but not the
	-- radial waves, so the two attacks demand different answers.
	for _, frame in Graybox.ring(ARENA_CENTER, config.CoverPillarRadius, config.CoverPillarCount, 30) do
		Graybox.part({
			name = "CoverPillar",
			size = Vector3.new(7, 12, 7),
			cframe = frame * CFrame.new(0, 6, 0),
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
		Vector3.new(230, 120, 230),
		CFrame.new(HUB_CENTER + Vector3.new(0, 55, 0)),
		zones
	)
	Graybox.mark(sanctuary, Contract.Tags.Zone, "zone_hub", { ZoneId = "hub_sanctuary" })

	local rangeZone = Graybox.volume(
		"RangeZone",
		Vector3.new(100, 120, 290),
		CFrame.new(RANGE_CENTER + Vector3.new(0, 55, 0)),
		zones
	)
	Graybox.mark(rangeZone, Contract.Tags.Zone, "zone_range", { ZoneId = "firing_range" })

	local arenaZone = Graybox.volume(
		"StormArenaZone",
		Vector3.new(200, 140, 200),
		CFrame.new(ARENA_CENTER + Vector3.new(0, 60, 0)),
		zones
	)
	Graybox.mark(arenaZone, Contract.Tags.Zone, "zone_storm_arena", { ZoneId = "storm_engine_arena" })
end

return WorldBuilderService
