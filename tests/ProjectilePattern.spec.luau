--!strict
--[[
	Determinism is the load-bearing property of the pattern system: the server
	hit-tests against positions it never sends, and the client draws positions
	it never receives. If these two diverge, players take damage from
	projectiles that were never on their screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProjectilePattern = require(Shared.Combat.ProjectilePattern)
local StormEngine = require(Shared.Config.Bosses.StormEngine)

return function(t)
	local function makeSpawn(seed: number, patternId: string)
		return {
			patternId = patternId,
			instanceId = 1,
			seed = seed,
			startTime = 0,
			origin = CFrame.new(0, 0, 0),
			targetPosition = Vector3.new(40, 0, 0),
			damage = 10,
			damageType = "Arc",
		}
	end

	t.describe("ProjectilePattern", function()
		t.describe("determinism", function()
			for patternId, definition in StormEngine.Patterns do
				t.it(`{patternId} builds identically from the same seed`, function()
					local spawn = makeSpawn(12345, patternId)
					local a = ProjectilePattern.build(definition, spawn)
					local b = ProjectilePattern.build(definition, spawn)

					t.expectEqual(#a, #b, "shot counts differ")
					for index, shot in a do
						local other = b[index]
						t.expectTrue((shot.origin - other.origin).Magnitude < 1e-6, "origins differ")
						t.expectTrue((shot.direction - other.direction).Magnitude < 1e-6, "directions differ")
						t.expectNear(shot.delay, other.delay, 1e-9, "delays differ")
					end
				end)

				t.it(`{patternId} positions are identical at the same elapsed time`, function()
					local spawn = makeSpawn(999, patternId)
					local shots = ProjectilePattern.build(definition, spawn)
					local elapsed = definition.TelegraphTime + definition.Lifetime * 0.5

					for _, shot in shots do
						local first = ProjectilePattern.positionAt(shot, definition, elapsed)
						local second = ProjectilePattern.positionAt(shot, definition, elapsed)
						if first and second then
							t.expectTrue((first - second).Magnitude < 1e-9, "position not deterministic")
						end
					end
				end)
			end
		end)

		t.describe("lifetime", function()
			t.it("a shot does not exist before its delay", function()
				local definition = StormEngine.Patterns.radial_wave
				local shots = ProjectilePattern.build(definition, makeSpawn(1, "radial_wave"))
				local shot = shots[1]
				t.expectEqual(ProjectilePattern.positionAt(shot, definition, shot.delay - 0.01), nil)
			end)

			t.it("a shot expires after its lifetime", function()
				local definition = StormEngine.Patterns.radial_wave
				local shots = ProjectilePattern.build(definition, makeSpawn(1, "radial_wave"))
				local shot = shots[1]
				local expired = shot.delay + definition.Lifetime + 0.01
				t.expectEqual(ProjectilePattern.positionAt(shot, definition, expired), nil)
			end)

			t.it("isFinished only reports true after the last shot expires", function()
				local definition = StormEngine.Patterns.radial_wave
				local shots = ProjectilePattern.build(definition, makeSpawn(1, "radial_wave"))

				local lastDelay = 0
				for _, shot in shots do
					lastDelay = math.max(lastDelay, shot.delay)
				end

				t.expectFalse(
					ProjectilePattern.isFinished(shots, definition, lastDelay + definition.Lifetime - 0.1)
				)
				t.expectTrue(
					ProjectilePattern.isFinished(shots, definition, lastDelay + definition.Lifetime + 0.1)
				)
			end)
		end)

		t.describe("radial wave gaps", function()
			t.it("leaves gaps, so the pattern is survivable at all", function()
				local definition = StormEngine.Patterns.radial_wave
				local shots = ProjectilePattern.build(definition, makeSpawn(7, "radial_wave"))
				local rings = definition.Rings or 1
				t.expectTrue(#shots < definition.Count * rings, "no projectiles were removed for gaps")
				t.expectTrue(#shots > definition.Count * rings * 0.5, "too many projectiles were removed")
			end)
		end)

		t.describe("hit evaluation", function()
			t.it("reports an overlap at the projectile's own position", function()
				local definition = StormEngine.Patterns.radial_wave
				local spawn = makeSpawn(3, "radial_wave")
				local shots = ProjectilePattern.build(definition, spawn)
				local elapsed = shots[1].delay + 0.5

				local position = ProjectilePattern.positionAt(shots[1], definition, elapsed)
				t.expectTrue(position ~= nil, "shot should exist at this time")

				local hits = ProjectilePattern.overlapping(shots, definition, elapsed, position :: Vector3, 2)
				t.expectTrue(#hits > 0, "a target standing on a projectile was not hit")
			end)

			t.it("respects the consumed set so one projectile cannot tick twice", function()
				local definition = StormEngine.Patterns.radial_wave
				local spawn = makeSpawn(3, "radial_wave")
				local shots = ProjectilePattern.build(definition, spawn)
				local elapsed = shots[1].delay + 0.5
				local position = ProjectilePattern.positionAt(shots[1], definition, elapsed) :: Vector3

				local consumed = {}
				local first = ProjectilePattern.overlapping(shots, definition, elapsed, position, 2, consumed)
				for _, index in first do
					consumed[index] = true
				end

				local second =
					ProjectilePattern.overlapping(shots, definition, elapsed, position, 2, consumed)
				t.expectEqual(#second, 0, "an already-consumed projectile hit again")
			end)

			t.it("does not hit a target standing far outside the pattern", function()
				local definition = StormEngine.Patterns.radial_wave
				local spawn = makeSpawn(3, "radial_wave")
				local shots = ProjectilePattern.build(definition, spawn)
				local hits =
					ProjectilePattern.overlapping(shots, definition, 0.9, Vector3.new(5000, 0, 5000), 2)
				t.expectEqual(#hits, 0)
			end)
		end)

		t.describe("readability contract", function()
			t.it("every pattern draws larger than it damages", function()
				for patternId, definition in StormEngine.Patterns do
					t.expectTrue(
						definition.VisualRadius > definition.ProjectileRadius,
						`{patternId} visual radius must exceed its hit radius`
					)
				end
			end)

			t.it("every pattern telegraphs before it damages", function()
				for patternId, definition in StormEngine.Patterns do
					t.expectTrue(definition.TelegraphTime > 0, `{patternId} has no telegraph`)
				end
			end)
		end)
	end)
end
