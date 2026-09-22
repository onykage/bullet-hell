--!strict
--[[
	Combat/ProjectilePattern.luau

	The performance bet described in §16.1, made concrete.

	A bullet-hell pattern is NEVER a set of replicated physical Parts. It is:

	    (pattern definition, seed, start timestamp, origin, target)

	...plus this pure module, which expands that record into projectile
	positions at any point in time. The server replicates ~80 bytes once per
	pattern; both sides then evaluate the identical function.

	  * Server calls `build` once and `positionAt` at its hit-check tick rate.
	  * Client calls `build` once and `positionAt` every frame to draw.

	Because it is pure and seeded, both sides agree without synchronisation.
	Nothing here may read workspace, os.clock, or math.random.
]]

local Types = require(script.Parent.Parent.Types)

type PatternDefinition = Types.PatternDefinition
type PatternSpawn = Types.PatternSpawn

export type ShotMode = "Linear" | "Orbit"

export type Shot = {
	mode: ShotMode,
	delay: number, -- seconds after pattern start before this shot exists
	origin: Vector3,
	direction: Vector3, -- Linear: travel direction. Orbit: initial radial offset direction.
	speed: number,
	radius: number, -- orbit radius, unused for Linear
	angularSpeed: number, -- degrees/sec, unused for Linear
	center: Vector3, -- orbit center, unused for Linear
}

local ProjectilePattern = {}

local function horizontalDirection(degrees: number): Vector3
	local radians = math.rad(degrees)
	return Vector3.new(math.cos(radians), 0, math.sin(radians))
end

local function angularDistance(a: number, b: number): number
	local difference = math.abs((a - b) % 360)
	return math.min(difference, 360 - difference)
end

local function buildRadialWave(definition: PatternDefinition, spawn: PatternSpawn): { Shot }
	local shots: { Shot } = {}
	local rings = definition.Rings or 1
	local ringInterval = definition.RingInterval or 0
	local gapCount = definition.GapCount or 0
	local gapWidth = definition.GapWidthDegrees or 0
	local rotationSpeed = definition.RotationSpeed or 0
	local origin = spawn.origin.Position + Vector3.new(0, 3, 0)

	for ring = 0, rings - 1 do
		local delay = definition.TelegraphTime + ring * ringInterval
		-- Gaps sweep between rings, so standing in one safe slot does not work.
		local gapRotation = rotationSpeed * delay

		for index = 0, definition.Count - 1 do
			local angle = (index / definition.Count) * 360

			local blocked = false
			for gap = 0, gapCount - 1 do
				local gapCenter = (gap / math.max(gapCount, 1)) * 360 + gapRotation
				if angularDistance(angle, gapCenter) < gapWidth * 0.5 then
					blocked = true
					break
				end
			end

			if not blocked then
				table.insert(shots, {
					mode = "Linear" :: ShotMode,
					delay = delay,
					origin = origin,
					direction = horizontalDirection(angle),
					speed = definition.Speed,
					radius = 0,
					angularSpeed = 0,
					center = origin,
				})
			end
		end
	end

	return shots
end

local function buildTargetedLine(definition: PatternDefinition, spawn: PatternSpawn): { Shot }
	local shots: { Shot } = {}
	local origin = spawn.origin.Position + Vector3.new(0, 4, 0)
	local target = spawn.targetPosition or (origin + spawn.origin.LookVector * 50)

	local flatTarget = Vector3.new(target.X, origin.Y, target.Z)
	local forward = (flatTarget - origin)
	if forward.Magnitude < 0.01 then
		forward = spawn.origin.LookVector * Vector3.new(1, 0, 1)
	end
	forward = forward.Unit
	local lateral = Vector3.new(-forward.Z, 0, forward.X)

	-- A seeded gap keeps the wall dodgeable while staying unpredictable.
	local rng = Random.new(spawn.seed)
	local gapSlot = rng:NextInteger(1, definition.Count)
	local spacing = 4.5
	local half = (definition.Count - 1) * 0.5

	for index = 1, definition.Count do
		if index == gapSlot or index == gapSlot + 1 then
			continue
		end

		local offset = (index - 1 - half) * spacing
		table.insert(shots, {
			mode = "Linear" :: ShotMode,
			delay = definition.TelegraphTime,
			origin = origin + lateral * offset,
			direction = forward,
			speed = definition.Speed,
			radius = 0,
			angularSpeed = 0,
			center = origin,
		})
	end

	return shots
end

local function buildOrbit(definition: PatternDefinition, spawn: PatternSpawn): { Shot }
	local shots: { Shot } = {}
	local center = spawn.origin.Position + Vector3.new(0, 4, 0)
	local orbitRadius = definition.OrbitRadius or 20

	for index = 0, definition.Count - 1 do
		local angle = (index / definition.Count) * 360
		table.insert(shots, {
			mode = "Orbit" :: ShotMode,
			delay = definition.TelegraphTime,
			origin = center,
			direction = horizontalDirection(angle),
			speed = 0,
			radius = orbitRadius,
			angularSpeed = definition.RotationSpeed or 30,
			center = center,
		})
	end

	return shots
end

local function buildSpiral(definition: PatternDefinition, spawn: PatternSpawn): { Shot }
	local shots: { Shot } = {}
	local arms = definition.SpiralArms or 3
	local rotationSpeed = definition.RotationSpeed or 45
	local origin = spawn.origin.Position + Vector3.new(0, 3, 0)
	local emissionInterval = 0.07

	for index = 0, definition.Count - 1 do
		local arm = index % arms
		local step = math.floor(index / arms)
		local delay = definition.TelegraphTime + step * emissionInterval
		local angle = (arm / arms) * 360 + rotationSpeed * (delay - definition.TelegraphTime)

		table.insert(shots, {
			mode = "Linear" :: ShotMode,
			delay = delay,
			origin = origin,
			direction = horizontalDirection(angle),
			speed = definition.Speed,
			radius = 0,
			angularSpeed = 0,
			center = origin,
		})
	end

	return shots
end

local BUILDERS: { [string]: (PatternDefinition, PatternSpawn) -> { Shot } } = {
	RadialWave = buildRadialWave,
	TargetedLine = buildTargetedLine,
	Orbit = buildOrbit,
	Spiral = buildSpiral,
}

--[[
	Expands a spawn record into its shot list. Pure and deterministic: the same
	arguments always produce the same result on server and client.
]]
function ProjectilePattern.build(definition: PatternDefinition, spawn: PatternSpawn): { Shot }
	local builder = BUILDERS[definition.Kind]
	assert(builder, `[ProjectilePattern] unsupported kind {definition.Kind}`)
	return builder(definition, spawn)
end

--[[
	Position of one shot at `elapsed` seconds after pattern start.
	Returns nil when the shot has not spawned yet or has expired.
]]
function ProjectilePattern.positionAt(shot: Shot, definition: PatternDefinition, elapsed: number): Vector3?
	local age = elapsed - shot.delay
	if age < 0 or age > definition.Lifetime then
		return nil
	end

	if shot.mode == "Orbit" then
		local angle = math.rad(shot.angularSpeed * age)
		local cos, sin = math.cos(angle), math.sin(angle)
		local offset = shot.direction * shot.radius
		local rotated =
			Vector3.new(offset.X * cos - offset.Z * sin, offset.Y, offset.X * sin + offset.Z * cos)
		return shot.center + rotated
	end

	return shot.origin + shot.direction * (shot.speed * age)
end

--[[
	True once every shot in the pattern has expired.
]]
function ProjectilePattern.isFinished(
	shots: { Shot },
	definition: PatternDefinition,
	elapsed: number
): boolean
	local lastDelay = 0
	for _, shot in shots do
		if shot.delay > lastDelay then
			lastDelay = shot.delay
		end
	end
	return elapsed > lastDelay + definition.Lifetime
end

--[[
	Server-side hit evaluation (§16.1: "simplified projectile paths ... or
	sampled positions"). Returns the indices of shots overlapping `position`.

	`consumed` lets the caller mark a shot as spent so one projectile cannot
	damage the same target on consecutive ticks.
]]
function ProjectilePattern.overlapping(
	shots: { Shot },
	definition: PatternDefinition,
	elapsed: number,
	position: Vector3,
	targetRadius: number,
	consumed: { [number]: boolean }?
): { number }
	local hits: { number } = {}
	local threshold = definition.ProjectileRadius + targetRadius
	local thresholdSquared = threshold * threshold

	for index, shot in shots do
		if consumed and consumed[index] then
			continue
		end

		local projectilePosition = ProjectilePattern.positionAt(shot, definition, elapsed)
		if not projectilePosition then
			continue
		end

		local delta = projectilePosition - position
		-- Vertical tolerance is generous: patterns are read on the XZ plane and
		-- punishing players for hitbox height would not be readable (§7.4).
		if math.abs(delta.Y) > 6 then
			continue
		end

		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat:Dot(flat) <= thresholdSquared then
			table.insert(hits, index)
		end
	end

	return hits
end

return ProjectilePattern
