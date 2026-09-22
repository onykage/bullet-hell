--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local DamageCalculator = require(Shared.Combat.DamageCalculator)

return function(t)
	local function context(overrides)
		local base = {
			attackerUserId = 1,
			sourceId = "test",
			weaponId = "frontier_rifle",
			damageType = "Kinetic",
			baseDamage = 100,
			hitPosition = Vector3.zero,
			hitRegion = "Body",
			isCritical = false,
			isPvP = false,
			sequenceId = 1,
		}
		for key, value in overrides or {} do
			base[key] = value
		end
		return base
	end

	t.describe("DamageCalculator", function()
		t.it("returns base damage with no modifiers in PvE", function()
			t.expectNear(DamageCalculator.compute(context()), 100, 1e-9)
		end)

		t.it("applies PvP scaling separately from PvE", function()
			local pve = DamageCalculator.compute(context())
			local pvp = DamageCalculator.compute(context({ isPvP = true }))
			t.expectNear(pvp, pve * Balance.Profiles.PvP.DamageMultiplier, 1e-9)
		end)

		t.it("applies modifiers in the documented order", function()
			-- (100 + 10) * 1.5 * 2 = 330
			local value = DamageCalculator.compute(context(), {
				flat = 10,
				additivePercent = 0.5,
				multiplicative = 2,
			})
			t.expectNear(value, 330, 1e-9)
		end)

		t.it("never exceeds the hard damage cap", function()
			local value = DamageCalculator.compute(context({ baseDamage = 1e9 }), { multiplicative = 1e9 })
			t.expectEqual(value, Balance.Limits.MaxDamagePerHit)
		end)

		t.it("never returns negative damage", function()
			local value = DamageCalculator.compute(context(), { multiplicative = -5 })
			t.expectTrue(value >= 0, "negative damage would heal the target")
		end)

		t.describe("hit regions", function()
			t.it("uses the named region when no explicit multiplier is given", function()
				t.expectEqual(DamageCalculator.regionMultiplier("Head", nil), Balance.HitRegions.Head)
				t.expectEqual(
					DamageCalculator.regionMultiplier("WeakPoint", nil),
					Balance.HitRegions.WeakPoint
				)
			end)

			t.it("falls back to Body for an unknown region", function()
				t.expectEqual(DamageCalculator.regionMultiplier("Elbow", nil), Balance.HitRegions.Body)
				t.expectEqual(DamageCalculator.regionMultiplier(nil, nil), Balance.HitRegions.Body)
			end)

			t.it("clamps an authored multiplier so a bad attribute cannot one-shot", function()
				-- A Studio-authored DamageMultiplier of 1000 must not be trusted.
				t.expectEqual(DamageCalculator.regionMultiplier("Body", 1000), Balance.HitRegions.WeakPoint)
				t.expectEqual(DamageCalculator.regionMultiplier("Body", -10), 0)
			end)
		end)
	end)
end
