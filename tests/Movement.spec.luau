--!strict
--[[
	Movement tuning invariants.

	These are not testing Roblox physics — they assert that the numbers in
	Config/Movement stay internally consistent, because the abilities are
	predicted on the client and revalidated on the server from this one module.
	A tuning change that breaks one of these makes the two sides disagree, and
	the symptom is honest players having abilities denied.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(Shared.Config.Movement)

return function(t)
	t.describe("Movement config", function()
		t.describe("constraint physics", function()
			t.it("uses a finite constraint force", function()
				-- math.huge makes the constraint solver no-op or produce NaN.
				-- This is the bug that made the first slide do nothing at all.
				t.expectTrue(MovementConfig.ConstraintForce < math.huge, "MaxForce must be finite")
				t.expectTrue(MovementConfig.ConstraintForce > 1e4, "MaxForce must actually move a character")
			end)
		end)

		t.describe("slide", function()
			local slide = MovementConfig.Slide

			t.it("is enterable from a sprint", function()
				t.expectTrue(
					MovementConfig.SprintSpeed >= slide.MinimumEntrySpeed,
					"sprinting must reach the slide entry speed, or slide is unreachable"
				)
			end)

			t.it("starts faster than it ends", function()
				t.expectTrue(
					slide.InitialSpeed > slide.MinimumExitSpeed,
					"slide would end on the frame it began"
				)
			end)

			t.it("has a start grace shorter than its duration", function()
				t.expectTrue(slide.StartGrace > 0, "without a grace window the exit check fires immediately")
				t.expectTrue(slide.StartGrace < slide.MaximumDuration, "grace must not outlast the slide")
			end)

			t.it("decelerates to its exit speed within the maximum duration", function()
				-- Otherwise the duration cap, not friction, is what ends every
				-- slide, and the friction tuning is decorative.
				local bleed = slide.Friction * slide.MaximumDuration
				t.expectTrue(
					slide.InitialSpeed - bleed <= slide.MinimumExitSpeed,
					"friction never brings the slide below its exit speed"
				)
			end)

			t.it("survives the server's entry tolerance", function()
				-- MovementService accepts 70% of the configured entry speed.
				t.expectTrue(slide.MinimumEntrySpeed * 0.7 < MovementConfig.SprintSpeed)
			end)
		end)

		t.describe("wall run", function()
			local wall = MovementConfig.WallRun

			t.it("is enterable at sprint speed", function()
				t.expectTrue(MovementConfig.SprintSpeed >= wall.MinimumEntrySpeed)
			end)

			t.it("loses height rather than holding it", function()
				-- A wall run that holds height is a platform, and players park
				-- on it instead of moving.
				t.expectTrue(wall.GravityScale > 0, "zero gravity turns the wall run into a hover")
				t.expectTrue(wall.GravityScale < 1, "full gravity makes the wall run pointless")
			end)

			t.it("requires travelling along the wall, not into it", function()
				t.expectTrue(
					wall.MinimumAlignment > 0,
					"any alignment would let players stick to walls head-on"
				)
				t.expectTrue(wall.MinimumAlignment < 1, "perfect alignment is unreachable in practice")
			end)

			t.it("caps the wall chain so players cannot climb out of an arena", function()
				-- This is the bound that separates the mechanic from the
				-- wallhop glitch it is modelled on.
				t.expectTrue(MovementConfig.Validation.MaxWallChain >= 1, "wall running would be unusable")
				t.expectTrue(
					MovementConfig.Validation.MaxWallChain <= 5,
					"too many chains is an unbounded climb"
				)
			end)

			t.it("cannot out-climb the arena ceiling", function()
				-- The whole reason the mechanic is bounded. If this fails, a
				-- player can wallhop out of the boss arena, which is exactly
				-- the glitch behaviour the design is trying to domesticate.
				local StormEngine = require(Shared.Config.Bosses.StormEngine)
				local jump = wall.WallJump

				-- This place sets its own gravity, so read it rather than
				-- assuming Roblox's default.
				local gravity = workspace.Gravity
				local function apex(speed: number): number
					return (speed * speed) / (2 * gravity)
				end

				-- Worst case from a standing start: a ground jump, then every
				-- allowed wall attach and wall jump converting fully to height.
				local reachable = apex(MovementConfig.JumpPower)
					+ MovementConfig.Validation.MaxWallChain
						* (apex(wall.AttachBoost) + apex(jump.UpwardSpeed))

				t.expectTrue(
					reachable < StormEngine.Graybox.CeilingHeight,
					`wall chaining reaches {math.floor(reachable)} studs, ceiling is {StormEngine.Graybox.CeilingHeight}`
				)
			end)
		end)

		t.describe("dash", function()
			t.it("grants invulnerability for less than its duration", function()
				local dash = MovementConfig.Dash
				t.expectTrue(
					dash.InvulnerabilityWindow <= dash.Duration,
					"i-frames outlasting the dash would be invisible to the player"
				)
			end)

			t.it("stays under the server speed ceiling", function()
				t.expectTrue(
					MovementConfig.Dash.Speed < MovementConfig.Validation.MaxPositionDeltaPerSecond,
					"the dash would trip the server's own anti-teleport check"
				)
			end)
		end)
	end)
end
