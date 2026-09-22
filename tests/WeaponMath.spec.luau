--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponMath = require(Shared.Combat.WeaponMath)
local Weapons = require(Shared.Config.Weapons)

return function(t)
	local rifle = Weapons.expect("frontier_rifle")
	local shotgun = Weapons.expect("breaker_shotgun")
	local sniper = Weapons.expect("longshot_sniper")

	t.describe("WeaponMath", function()
		t.describe("falloff", function()
			t.it("is neutral inside the falloff start", function()
				t.expectEqual(WeaponMath.falloffMultiplier(rifle.BaseStats, 10), 1)
				t.expectEqual(WeaponMath.falloffMultiplier(rifle.BaseStats, rifle.BaseStats.FalloffStart), 1)
			end)

			t.it("bottoms out at the weapon's minimum past max range", function()
				t.expectEqual(
					WeaponMath.falloffMultiplier(rifle.BaseStats, rifle.BaseStats.Range * 2),
					rifle.BaseStats.FalloffMinimum
				)
			end)

			t.it("decreases monotonically across the falloff band", function()
				local stats = shotgun.BaseStats
				local previous = math.huge
				for distance = stats.FalloffStart, stats.Range, 5 do
					local value = WeaponMath.falloffMultiplier(stats, distance)
					t.expectTrue(value <= previous + 1e-9, "falloff increased with distance")
					previous = value
				end
			end)

			t.it("never applies falloff to the marksman rifle", function()
				-- Its identity is that distance costs it nothing (§8.1).
				t.expectEqual(WeaponMath.falloffMultiplier(sniper.BaseStats, 900), 1)
			end)
		end)

		t.describe("spread", function()
			t.it("returns the original direction at zero spread", function()
				local direction = Vector3.new(0, 0, -1)
				local result = WeaponMath.applySpread(direction, 0, Random.new(1))
				t.expectTrue((result - direction).Magnitude < 1e-6)
			end)

			t.it("stays inside the requested cone", function()
				local direction = Vector3.new(0, 0, -1)
				local rng = Random.new(42)
				for _ = 1, 400 do
					local result = WeaponMath.applySpread(direction, 5, rng)
					local angle = math.deg(math.acos(math.clamp(result:Dot(direction), -1, 1)))
					t.expectTrue(angle <= 5 + 1e-6, `pellet at {angle}° exceeded the 5° cone`)
				end
			end)

			t.it("produces unit vectors", function()
				local rng = Random.new(7)
				for _ = 1, 50 do
					local result = WeaponMath.applySpread(Vector3.new(1, 2, 3), 12, rng)
					t.expectNear(result.Magnitude, 1, 1e-6)
				end
			end)

			t.it("is reproducible from the same seed", function()
				local a = WeaponMath.applySpread(Vector3.zAxis, 8, Random.new(99))
				local b = WeaponMath.applySpread(Vector3.zAxis, 8, Random.new(99))
				t.expectTrue((a - b).Magnitude < 1e-9)
			end)
		end)

		t.describe("bloom", function()
			t.it("accumulates but is capped", function()
				local bloom = 0
				for _ = 1, 100 do
					bloom = WeaponMath.addBloom(rifle.BaseStats, bloom)
				end
				t.expectTrue(bloom <= rifle.BaseStats.SpreadDegrees * 3 + 1e-9, "bloom exceeded its ceiling")
			end)

			t.it("decays to zero and never below", function()
				local bloom = WeaponMath.decayBloom(rifle.BaseStats, 1.0, 100)
				t.expectEqual(bloom, 0)
			end)

			t.it("aiming is tighter than hip fire at equal bloom", function()
				local hip = WeaponMath.currentSpread(rifle.BaseStats, 0.5, false)
				local aimed = WeaponMath.currentSpread(rifle.BaseStats, 0.5, true)
				t.expectTrue(aimed < hip, "aiming did not tighten the cone")
			end)
		end)

		t.describe("cadence validation", function()
			t.it("allows the weapon's nominal fire rate", function()
				local interval = WeaponMath.minimumShotInterval(rifle.BaseStats)
				t.expectTrue(interval < 1 / rifle.BaseStats.FireRate, "no tolerance for network jitter")
			end)

			t.it("still rejects clearly impossible rates", function()
				local interval = WeaponMath.minimumShotInterval(rifle.BaseStats)
				-- Double the legal rate must not slip through the tolerance.
				t.expectTrue(interval > (1 / rifle.BaseStats.FireRate) * 0.5, "tolerance is too generous")
			end)
		end)
	end)
end
