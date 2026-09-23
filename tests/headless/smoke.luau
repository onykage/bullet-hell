--!nocheck
--[[
	tests/headless/smoke.luau

	Boots the server on Lune and asserts the world it builds.

	This is the test that catches "the map does not load": it fails loudly, with
	a stack trace, on any error during service Init or Start, and then inspects
	the geometry and tagging that the world builder actually produced.

	Run with `make headless`.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

local Runtime = require("./runtime")

local ROOT = string.gsub(process.cwd, "/$", "")

local passed, failed = 0, 0
local function check(label: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(`  ok    {label}`)
	else
		failed += 1
		print(`  FAIL  {label}`)
		if detail and detail ~= "" then
			print(`          {detail}`)
		end
	end
end

local function finish()
	print(`\n{passed} passed, {failed} failed`)
	if failed > 0 then
		process.exit(1)
	end
end

print("headless smoke test\n")

local runtime = Runtime.new(ROOT)

--[[
	The service order is read out of ServerBootstrap rather than duplicated, so
	this harness cannot drift from the real boot sequence.
]]
local bootstrapSource = fs.readFile(`{ROOT}/src/ServerScriptService/ServerBootstrap.server.luau`)
local orderBlock = string.match(bootstrapSource, "local SERVICE_ORDER = {(.-)}")
assert(orderBlock, "could not find SERVICE_ORDER in ServerBootstrap")

local serviceOrder = {}
for name in string.gmatch(orderBlock, '"([%w_]+)"') do
	table.insert(serviceOrder, name)
end
check(`read {#serviceOrder} services from ServerBootstrap`, #serviceOrder > 0)

print("\nboot:")
local ok, err = runtime:bootServer(serviceOrder)
runtime:flushDeferred()
check("server boots without error", ok, err)

for _, line in runtime.prints do
	print(`        print: {line}`)
end

if not ok then
	for _, line in runtime.warnings do
		print(`        warn:  {line}`)
	end
	finish()
	return
end

-- World integrity -----------------------------------------------------------

print("\nworld:")

local workspaceInstance = runtime.workspace
local world = workspaceInstance:FindFirstChild("World")
check("Workspace.World exists", world ~= nil)

if not world then
	finish()
	return
end

check(`world has geometry ({#world:GetDescendants()} instances)`, #world:GetDescendants() > 50)

local ground = world:FindFirstChild("Ground")
check("Ground container exists", ground ~= nil)

if ground then
	local bedrock = ground:FindFirstChild("Bedrock")
	check("Bedrock exists", bedrock ~= nil)

	if bedrock then
		check("Bedrock is collidable", bedrock.CanCollide == true)
		local top = bedrock.Position.Y + bedrock.Size.Y / 2
		check("Bedrock top face is y=0", math.abs(top) < 0.001, `top is {top}`)
	end

	local barriers = 0
	for _, child in ground:GetChildren() do
		if string.match(child.Name, "^PerimeterBarrier") then
			barriers += 1
		end
	end
	check("perimeter enclosed on 4 sides", barriers == 4, `found {barriers}`)
end

local spawns = 0
for _, descendant in world:GetDescendants() do
	if descendant.ClassName == "SpawnLocation" then
		spawns += 1
	end
end
check("a SpawnLocation exists for players to arrive at", spawns >= 1, `found {spawns}`)

--[[
	The single-surface rule: bedrock is the only thing anything stands on.
	A collidable decorative floor reintroduces exactly the seams and lips that
	ADR 0004 exists to remove.
]]
local collidableFloors = {}
for _, descendant in workspaceInstance:GetDescendants() do
	local isFloor = string.match(descendant.Name, "Floor") or string.match(descendant.Name, "^Marker%d")
	if isFloor and descendant.ClassName == "Part" and descendant.CanCollide then
		table.insert(collidableFloors, descendant:GetFullName())
	end
end
check("no decorative surface is collidable", #collidableFloors == 0, table.concat(collidableFloors, ", "))

-- Contract ------------------------------------------------------------------

print("\ncontract:")

local Contract = runtime:require(runtime.shared.Contract)
local collectionService = runtime.services.CollectionService

local expectedTags = {
	{ Contract.Tags.PlayerSpawn, 5 },
	{ Contract.Tags.ArenaEntrance, 1 },
	{ Contract.Tags.BossMarker, 1 },
	{ Contract.Tags.AttackOrigin, 4 },
	{ Contract.Tags.Conductor, 4 },
	{ Contract.Tags.Zone, 3 },
	{ Contract.Tags.EnemySpawnVolume, 2 },
	{ Contract.Tags.HitRegion, 1 },
}

for _, entry in expectedTags do
	local tag, expected = entry[1], entry[2]
	local tagged = collectionService:GetTagged(tag)
	check(`{tag}: {#tagged} tagged (need >= {expected})`, #tagged >= expected)
end

local violations = {}
for tag in Contract.Attributes do
	for _, instance in collectionService:GetTagged(tag) do
		local valid, reason = Contract.validateInstance(instance, tag)
		if not valid then
			table.insert(violations, reason)
		end
	end
end
check(
	"every tagged instance satisfies its contract",
	#violations == 0,
	table.concat(violations, "\n          ")
)

-- Arena ---------------------------------------------------------------------

print("\narena:")

local StormEngine = runtime:require(runtime.shared.Config.Bosses.StormEngine)
local config = StormEngine.Graybox

local arena = world:FindFirstChild("StormEngineArena")
check("arena container exists", arena ~= nil)

--[[
	BossService finds its markers by tag and attribute at runtime. If this
	lookup fails, the boss silently never spawns.
]]
local bossSpawn = nil
for _, instance in collectionService:GetTagged(Contract.Tags.BossMarker) do
	if instance:GetAttribute("MarkerId") == Contract.Markers.BossSpawn then
		bossSpawn = instance
	end
end
check("BossService can find its spawn marker", bossSpawn ~= nil)

if arena and bossSpawn then
	local center = bossSpawn.Position

	local walls = {}
	for _, child in arena:GetChildren() do
		if child.Name == "ArenaWall" then
			table.insert(walls, child)
		end
	end
	check(`arena wall has {#walls} segments`, #walls >= 12)

	-- The seal test, from the geometry itself rather than from the config:
	-- adjacent segments must overlap, not merely meet at their corners.
	if #walls >= 3 then
		local chord = 2 * config.ArenaRadius * math.sin(math.pi / #walls)
		local width = walls[1].Size.X
		check(
			`wall segments overlap (width {string.format("%.1f", width)} > chord {string.format("%.1f", chord)})`,
			width > chord
		)

		-- Every segment must sit on the ring, or the ring is not a ring.
		local offRing = 0
		for _, wall in walls do
			local flat = (wall.Position - center) * Vector3.new(1, 0, 1)
			if math.abs(flat.Magnitude - config.ArenaRadius) > 1 then
				offRing += 1
			end
		end
		check("every wall segment sits on the ring", offRing == 0, `{offRing} off-ring`)
	end

	local ceiling = arena:FindFirstChild("ArenaCeiling")
	check("arena has a ceiling", ceiling ~= nil)
	if ceiling then
		check(
			"ceiling sits above the wall",
			ceiling.Position.Y > config.WallHeight,
			`ceiling y={ceiling.Position.Y}, wall height={config.WallHeight}`
		)
	end

	-- Anything the fight needs must be inside the wall ring, or players cannot
	-- reach it and patterns emit from outside the arena.
	local outside = {}
	for _, tag in { Contract.Tags.Conductor, Contract.Tags.AttackOrigin } do
		for _, instance in collectionService:GetTagged(tag) do
			local flat = (instance.Position - center) * Vector3.new(1, 0, 1)
			if flat.Magnitude >= config.ArenaRadius then
				table.insert(outside, `{instance.Name} at {string.format("%.0f", flat.Magnitude)} studs`)
			end
		end
	end
	check("conductors and attack origins are inside the arena", #outside == 0, table.concat(outside, ", "))

	local arenaSpawnsOutside = {}
	for _, instance in collectionService:GetTagged(Contract.Tags.PlayerSpawn) do
		if instance:GetAttribute("SpawnType") == "Arena" then
			local flat = (instance.Position - center) * Vector3.new(1, 0, 1)
			if flat.Magnitude >= config.ArenaRadius then
				table.insert(arenaSpawnsOutside, instance.Name)
			end
		end
	end
	check(
		"arena spawns are inside the arena",
		#arenaSpawnsOutside == 0,
		table.concat(arenaSpawnsOutside, ", ")
	)
end

-- Everything the world builder placed must sit over bedrock, or it is floating
-- above a void that a player can reach.
if ground then
	local bedrock = ground:FindFirstChild("Bedrock")
	if bedrock then
		local halfX = bedrock.Size.X / 2
		local halfZ = bedrock.Size.Z / 2
		local centerPosition = bedrock.Position

		local floating = {}
		for _, descendant in world:GetDescendants() do
			if descendant.ClassName ~= "Part" or descendant == bedrock then
				continue
			end
			if string.match(descendant.Name, "^PerimeterBarrier") then
				continue
			end
			local offset = descendant.Position - centerPosition
			if math.abs(offset.X) > halfX or math.abs(offset.Z) > halfZ then
				table.insert(
					floating,
					`{descendant.Name} at ({string.format("%.0f", descendant.Position.X)}, {string.format(
						"%.0f",
						descendant.Position.Z
					)})`
				)
			end
		end
		check("nothing is placed beyond the bedrock footprint", #floating == 0, table.concat(floating, ", "))
	end
end

-- Enemies -------------------------------------------------------------------

print("\nenemies:")

local runtimeFolder = workspaceInstance:FindFirstChild("Runtime")
local enemyFolder = runtimeFolder and runtimeFolder:FindFirstChild("Enemies")
check("enemy container exists", enemyFolder ~= nil)

if enemyFolder then
	local enemies = #enemyFolder:GetChildren()
	check(`enemies spawned from tagged volumes ({enemies})`, enemies >= 5)

	local missingRoot = {}
	for _, model in enemyFolder:GetChildren() do
		if not model:FindFirstChild("HumanoidRootPart") then
			table.insert(missingRoot, model.Name)
		end
	end
	check("every enemy has a root part", #missingRoot == 0, table.concat(missingRoot, ", "))
end

print("\nwarnings during boot:")
if #runtime.warnings == 0 then
	print("        (none)")
end
for _, line in runtime.warnings do
	print(`        warn: {line}`)
end

finish()
