--!strict
--[[
	These are the exploit-oriented tests the scaffold requires for every remote
	(§C18). Each case is a payload a modified client can actually send.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RateLimits = require(Shared.Network.RateLimits)
local Schemas = require(Shared.Network.Schemas)

return function(t)
	local function validFire()
		return {
			sequenceId = 1,
			origin = Vector3.new(0, 5, 0),
			directions = { Vector3.new(0, 0, -1) },
			clientTime = 100,
		}
	end

	t.describe("Schemas", function()
		t.describe("fire request", function()
			t.it("accepts a well-formed payload", function()
				local ok = Schemas.validateFireRequest(validFire())
				t.expectTrue(ok)
			end)

			t.it("rejects a non-table payload", function()
				t.expectFalse((Schemas.validateFireRequest("hello")))
				t.expectFalse((Schemas.validateFireRequest(nil)))
				t.expectFalse((Schemas.validateFireRequest(42)))
			end)

			t.it("rejects unknown fields rather than ignoring them", function()
				local payload = validFire()
				payload.damage = 99999
				t.expectFalse((Schemas.validateFireRequest(payload)))
			end)

			t.it("rejects NaN and infinite vectors", function()
				local payload = validFire()
				payload.origin = Vector3.new(0 / 0, 0, 0)
				t.expectFalse((Schemas.validateFireRequest(payload)))

				payload = validFire()
				payload.origin = Vector3.new(math.huge, 0, 0)
				t.expectFalse((Schemas.validateFireRequest(payload)))
			end)

			t.it("rejects out-of-world coordinates", function()
				local payload = validFire()
				payload.origin = Vector3.new(1e9, 0, 0)
				t.expectFalse((Schemas.validateFireRequest(payload)))
			end)

			t.it("rejects a pellet flood", function()
				local payload = validFire()
				payload.directions = {}
				for index = 1, 5000 do
					payload.directions[index] = Vector3.new(0, 0, -1)
				end
				t.expectFalse((Schemas.validateFireRequest(payload)))
			end)

			t.it("rejects an empty direction list", function()
				local payload = validFire()
				payload.directions = {}
				t.expectFalse((Schemas.validateFireRequest(payload)))
			end)

			t.it("rejects a zero-magnitude direction", function()
				local payload = validFire()
				payload.directions = { Vector3.zero }
				t.expectFalse((Schemas.validateFireRequest(payload)))
			end)

			t.it("rejects keyed entries smuggled into the direction array", function()
				local payload = validFire()
				payload.directions = { Vector3.new(0, 0, -1) }
				(payload.directions :: any).sneaky = Vector3.new(1, 0, 0)
				t.expectFalse((Schemas.validateFireRequest(payload)))
			end)

			t.it("rejects a negative or fractional sequence id", function()
				local payload = validFire()
				payload.sequenceId = -5
				t.expectFalse((Schemas.validateFireRequest(payload)))

				payload = validFire()
				payload.sequenceId = 1.5
				t.expectFalse((Schemas.validateFireRequest(payload)))
			end)

			t.it("normalises directions to unit length", function()
				local payload = validFire()
				payload.directions = { Vector3.new(0, 0, -17) }
				local ok, cleaned = Schemas.validateFireRequest(payload)
				t.expectTrue(ok)
				t.expectNear(cleaned.directions[1].Magnitude, 1, 1e-6)
			end)
		end)

		t.describe("movement request", function()
			t.it("rejects an unknown ability name", function()
				for _, ability in { "Teleport", "Fly", "NoClip", "" } do
					t.expectFalse((Schemas.validateMovementRequest({
						ability = ability,
						direction = Vector3.new(0, 0, -1),
						clientTime = 1,
					})), `{ability} should have been rejected`)
				end
			end)

			t.it("accepts every declared ability", function()
				for _, ability in { "Slide", "DoubleJump", "Dash", "WallRun", "WallJump" } do
					local ok = Schemas.validateMovementRequest({
						ability = ability,
						direction = Vector3.new(0, 0, -1),
						clientTime = 1,
					})
					t.expectTrue(ok, `{ability} was rejected`)
				end
			end)
		end)

		t.describe("equip request", function()
			t.it("rejects an oversized weapon id", function()
				t.expectFalse((Schemas.validateEquipRequest({ weaponId = string.rep("a", 500) })))
			end)

			t.it("rejects an empty weapon id", function()
				t.expectFalse((Schemas.validateEquipRequest({ weaponId = "" })))
			end)
		end)
	end)

	t.describe("RateLimits", function()
		t.it("allows a normal burst then throttles", function()
			local userId = -1001
			local budget = RateLimits.Budgets.FireWeapon
			local allowed = 0
			-- All at the same instant, so the bucket cannot refill.
			for _ = 1, budget.capacity + 20 do
				if RateLimits.consume(userId, "FireWeapon", 1000) then
					allowed += 1
				end
			end
			t.expectEqual(allowed, budget.capacity, "burst allowance did not match capacity")
			t.expectTrue(RateLimits.rejectionCount(userId, "FireWeapon") > 0, "rejections were not recorded")
			RateLimits.clearPlayer(userId)
		end)

		t.it("refills over time", function()
			local userId = -1002
			for _ = 1, RateLimits.Budgets.ReloadWeapon.capacity do
				RateLimits.consume(userId, "ReloadWeapon", 2000)
			end
			t.expectFalse(RateLimits.consume(userId, "ReloadWeapon", 2000), "bucket should be empty")
			t.expectTrue(RateLimits.consume(userId, "ReloadWeapon", 2010), "bucket should have refilled")
			RateLimits.clearPlayer(userId)
		end)

		t.it("errors on an undeclared action rather than allowing it", function()
			t.expectError(function()
				RateLimits.consume(-1003, "NotARealAction")
			end)
		end)
	end)
end
