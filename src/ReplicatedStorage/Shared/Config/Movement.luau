--!strict
--[[
	Config/Movement.luau

	Tuning for the movement kit: slide, double jump, dash, and wall run.

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

--[[
	Physics notes that apply to every constraint-driven ability below.

	MaxForce is a large FINITE number, never math.huge. An infinite MaxForce
	makes the constraint solver produce NaN or silently no-op, which is what
	made the first slide implementation do nothing at all.

	Every constraint preserves the character's own Y velocity rather than
	pinning it to zero. Pinning Y means gravity stops applying: the character
	hovers, never re-contacts the ground, and any grounded check fails forever.
]]
Movement.ConstraintForce = 1e6

Movement.Slide = {
	-- Entry requires real forward momentum, otherwise slide becomes a free
	-- crouch-spam speed boost.
	MinimumEntrySpeed = 19,
	InitialSpeed = 42,
	Friction = 26, -- studs/s^2 bled off while sliding
	MinimumExitSpeed = 14, -- below this the slide ends
	MaximumDuration = 1.2,
	Cooldown = 0.65,
	CameraHeightDelta = -1.4,
	-- Sliding downhill should feel rewarding but not become infinite.
	SlopeAcceleration = 18,
	MaximumSpeed = 64,
	-- The slide cannot cancel itself during this opening window. Starting a
	-- slide briefly disturbs the character's contact with the floor, and
	-- without a grace period the exit check fires on the first frame.
	StartGrace = 0.18,
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
	-- True cancels gravity for the dash duration, so an air dash is flat and
	-- readable instead of arcing into the floor.
	VerticalHold = true,
}

--[[
	Wall run.

	Roblox has a famous unpatchable movement glitch — the "wallhop" — where
	clipping a leg into the seam between two parts makes the Humanoid emit
	`Landed`, refunding a jump and letting players climb any wall built from
	stacked parts. It has been in the engine since 2013.

	Rather than fighting it, this is the sanctioned version: walls genuinely do
	refresh your air options, but on our terms. The part of the glitch that
	would wreck a bullet-hell arena is the *unbounded* vertical climb, so the
	limits below are the whole point:

	  * a wall run is time-boxed and loses height the whole way
	  * the same wall cannot be re-attached without touching ground or a
	    different wall first, which is what kills infinite ladders
	  * a wall jump refunds the air jump once, not once per seam

	See docs/decisions/0003-wall-run.md.
]]
Movement.WallRun = {
	-- How far to the side a wall may be and still be grabbable.
	DetectionDistance = 3.4,
	-- Minimum horizontal speed to attach. Wall running is a momentum move.
	MinimumEntrySpeed = 16,
	-- How aligned travel must be with the wall's tangent, as a dot product.
	-- Below this the player is running at the wall, not along it.
	MinimumAlignment = 0.45,
	Speed = 34,
	MaximumDuration = 1.6,
	Cooldown = 0.35,
	-- Gravity during a run. Not zero: a wall run that holds height is a
	-- platform, and players will simply park on it.
	GravityScale = 0.22,
	-- A small upward kick on attach so entering a run feels like a vault.
	AttachBoost = 12,
	-- Camera roll toward the wall, in degrees. Readability: you should be able
	-- to tell you are wall running without looking at your feet.
	CameraTilt = 9,
	-- Cannot attach again below this height above the ground, so a wall run
	-- cannot be chained into a hover just above the floor.
	MinimumHeightAboveGround = 2.5,

	WallJump = {
		-- Outward from the wall, and upward.
		OutwardSpeed = 42,
		UpwardSpeed = 48,
		-- The sanctioned wallhop: a wall jump refunds the air jump.
		RefundsAirJump = true,
		Cooldown = 0.2,
	},
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
	-- Consecutive wall attaches allowed without touching the ground. This is
	-- the hard stop on climbing out of an arena by alternating walls.
	MaxWallChain = 3,
}

table.freeze(Movement)
return Movement
