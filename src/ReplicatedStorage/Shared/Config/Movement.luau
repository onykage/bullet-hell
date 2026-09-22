--!strict
--[[
	Config/Movement.luau

	Tuning for the milestone-1 movement kit: slide, double jump, dash.

	These values are the contract between MovementController (predicts and plays
	the motion locally for feel) and MovementService (revalidates cooldowns,
	grounding, and resulting displacement). Both read this module, so a tuning
	change can never desync prediction from validation.
]]

local Movement = {}

Movement.BaseWalkSpeed = 18
Movement.SprintSpeed = 26
Movement.CrouchSpeed = 9
Movement.JumpPower = 52

Movement.Slide = {
	-- Entry requires real forward momentum, otherwise slide becomes a free
	-- crouch-spam speed boost.
	MinimumEntrySpeed = 20,
	InitialSpeed = 42,
	Friction = 26, -- studs/s^2 bled off while sliding
	MinimumExitSpeed = 14, -- below this the slide ends
	MaximumDuration = 1.2,
	Cooldown = 0.65,
	HipHeightDelta = -1.1,
	CameraHeightDelta = -1.4,
	-- Sliding downhill should feel rewarding but not become infinite.
	SlopeAcceleration = 18,
	MaximumSpeed = 64,
}

Movement.DoubleJump = {
	MaxAirJumps = 1,
	Power = 46,
	-- Cancels downward velocity so a late double jump still saves you; this is
	-- the behaviour players expect from Roblox platformers.
	CancelFallVelocity = true,
	Cooldown = 0.25,
	-- Coyote time: ground jump remains available briefly after leaving a ledge.
	CoyoteTime = 0.12,
}

Movement.Dash = {
	Speed = 78,
	Duration = 0.18,
	Cooldown = 1.4,
	-- Brief damage immunity: this is what makes dense patterns survivable and
	-- is the OnDodge trigger point for the mod system (§8.6).
	InvulnerabilityWindow = 0.14,
	AirDashes = 1,
	VerticalHold = true, -- cancel gravity for the dash duration
}

--[[
	Server validation tolerances. Prediction runs on the client, so the server
	allows a small margin before rejecting — but never enough to matter (§15.1).
]]
Movement.Validation = {
	CooldownGrace = 0.08, -- seconds of leniency on ability cooldowns
	MaxPositionDeltaPerSecond = 120, -- hard speed ceiling, includes dash
	GroundedRayLength = 4.5,
	MaxClientTimeSkew = 1.0,
}

table.freeze(Movement)
return Movement
