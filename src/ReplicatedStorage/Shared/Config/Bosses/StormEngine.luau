--!strict
--[[
	Config/Bosses/StormEngine.luau

	The vertical-slice boss (§19.3).

	  Phase one   — radial waves with rotating gaps; destroy exposed conductors
	                to open damage windows.
	  Transition  — forced traversal through a moving pattern.
	  Phase two   — targeted lines + orbiting projectiles + repair drones.
	  Enrage      — patterns speed up; boss damage does NOT inflate (§19.3).

	Every attack declares telegraph / execute / recover and a selection weight,
	per the attack module contract (§7.3). BossService never hard-codes timing.
]]

local StormEngine = {}

StormEngine.Id = "storm_engine"
StormEngine.DisplayName = "The Storm Engine"
StormEngine.ArenaId = "storm_engine_arena"

StormEngine.Health = {
	-- Scales with party size so 1-4 players can both complete it (§20.3).
	BasePerPlayer = 2600,
	SoloMultiplier = 1.0,
	PhaseTwoThreshold = 0.5, -- fraction of max health that triggers Transition
	EnrageAtSeconds = 300,
}

StormEngine.Conductors = {
	Count = 4,
	Health = 320,
	-- While a conductor is alive the boss takes reduced damage; breaking all of
	-- them opens the damage window. This is the phase-one skill test.
	DamageReductionPerConductor = 0.22,
	RespawnSeconds = 18,
	WindowSeconds = 12,
}

StormEngine.Drones = {
	MaxAlive = 3,
	Health = 180,
	SpawnInterval = 9,
	HealPerSecond = 14, -- boss regen while a drone lives (target prioritisation)
}

--[[
	Pattern definitions. Colors follow the readability language (§7.4):
	  hostile projectile  = warm orange
	  unblockable         = magenta
	  environmental       = cyan
	VisualRadius is deliberately larger than ProjectileRadius so a graze reads
	as a miss rather than an unexplained hit.
]]
StormEngine.Patterns = {
	radial_wave = {
		Id = "radial_wave",
		Kind = "RadialWave",
		Count = 48,
		Speed = 34,
		Lifetime = 4.5,
		ProjectileRadius = 1.0,
		VisualRadius = 1.4,
		TelegraphTime = 0.85,
		Color = Color3.fromRGB(255, 138, 48),
		Damage = 12,
		DamageType = "Arc",
		GapCount = 3,
		GapWidthDegrees = 34,
		RotationSpeed = 22, -- degrees/sec; makes gaps sweep
		Rings = 3,
		RingInterval = 0.75,
	},

	targeted_line = {
		Id = "targeted_line",
		Kind = "TargetedLine",
		Count = 9,
		Speed = 62,
		Lifetime = 3.0,
		ProjectileRadius = 0.9,
		VisualRadius = 1.25,
		TelegraphTime = 1.1,
		Color = Color3.fromRGB(255, 96, 160),
		Damage = 18,
		DamageType = "Arc",
	},

	orbit_field = {
		Id = "orbit_field",
		Kind = "Orbit",
		Count = 16,
		Speed = 0, -- orbit uses RotationSpeed, not linear speed
		Lifetime = 8.0,
		ProjectileRadius = 1.1,
		VisualRadius = 1.5,
		TelegraphTime = 0.6,
		Color = Color3.fromRGB(120, 210, 255),
		Damage = 10,
		DamageType = "Arc",
		OrbitRadius = 26,
		RotationSpeed = 46,
	},

	spiral_sweep = {
		Id = "spiral_sweep",
		Kind = "Spiral",
		Count = 60,
		Speed = 28,
		Lifetime = 6.0,
		ProjectileRadius = 0.95,
		VisualRadius = 1.3,
		TelegraphTime = 0.9,
		Color = Color3.fromRGB(255, 176, 64),
		Damage = 14,
		DamageType = "Arc",
		SpiralArms = 4,
		RotationSpeed = 64,
	},
}

--[[
	Attacks: which pattern, in which phases, with what cadence.
	Weights drive weighted-random selection among attacks legal in the phase.
]]
StormEngine.Attacks = {
	{
		Id = "wave_burst",
		PatternId = "radial_wave",
		Phases = { PhaseOne = true, PhaseTwo = true, Enraged = true },
		TelegraphSeconds = 0.85,
		ExecuteSeconds = 2.4,
		RecoverSeconds = 1.6,
		Cooldown = 6.0,
		Weight = 3,
		Targeting = "Self",
		AudioCue = "storm_wave",
	},
	{
		Id = "conductor_lance",
		PatternId = "targeted_line",
		Phases = { PhaseOne = true, PhaseTwo = true, Enraged = true },
		TelegraphSeconds = 1.1,
		ExecuteSeconds = 1.2,
		RecoverSeconds = 1.2,
		Cooldown = 7.5,
		Weight = 2,
		Targeting = "RandomPlayer",
		AudioCue = "storm_lance",
	},
	{
		Id = "containment_ring",
		PatternId = "orbit_field",
		Phases = { PhaseTwo = true, Enraged = true },
		TelegraphSeconds = 0.6,
		ExecuteSeconds = 8.0,
		RecoverSeconds = 0.8,
		Cooldown = 14.0,
		Weight = 2,
		Targeting = "Self",
		AudioCue = "storm_ring",
	},
	{
		Id = "cascade",
		PatternId = "spiral_sweep",
		Phases = { Transition = true, PhaseTwo = true, Enraged = true },
		TelegraphSeconds = 0.9,
		ExecuteSeconds = 5.0,
		RecoverSeconds = 2.0,
		Cooldown = 12.0,
		Weight = 2,
		Targeting = "Self",
		AudioCue = "storm_cascade",
	},
}

StormEngine.PhaseTiming = {
	PreparingSeconds = 2.0,
	IntroSeconds = 4.0,
	TransitionSeconds = 6.0,
	DefeatedSeconds = 3.5,
	RewardsSeconds = 5.0,
	ResetSeconds = 8.0,
	-- Enrage multiplies pattern speed and shortens cooldowns; damage is
	-- deliberately untouched.
	EnrageSpeedMultiplier = 1.35,
	EnrageCooldownMultiplier = 0.7,
}

StormEngine.Graybox = {
	-- Used by WorldBuilder when the Studio workstream has not supplied geometry.
	ArenaRadius = 78,
	WallHeight = 34,
	CoverPillarCount = 6,
	CoverPillarRadius = 46,
	BossHeight = 22,
	ConductorRadius = 58,
	AttackOriginCount = 4,
	AttackOriginRadius = 12,
	PlayerSpawnCount = 4,
	PlayerSpawnRadius = 66,
}

table.freeze(StormEngine)
return StormEngine
