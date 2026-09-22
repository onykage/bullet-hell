--!strict
--[[
	Config/Balance.luau — global combat coefficients and safety limits.

	PvE and PvP are tuned independently without changing weapon identity (§6.5).
	Hard caps exist so no combination of mods and skills can produce an
	unbounded value (§22 "Build imbalance").
]]

local Balance = {}

Balance.Player = {
	MaxHealth = 100,
	MaxShield = 50,
	ShieldRegenDelay = 5.0,
	ShieldRegenPerSecond = 12,
	RespawnSeconds = 4,
	SpawnProtectionSeconds = 6,
}

-- Applied after the weapon's own numbers, by context.
Balance.Profiles = {
	PvE = {
		DamageMultiplier = 1.0,
		CriticalMultiplier = 1.0,
		StaggerMultiplier = 1.0,
		StatusDurationMultiplier = 1.0,
	},
	PvP = {
		DamageMultiplier = 0.72,
		CriticalMultiplier = 0.85,
		StaggerMultiplier = 0.5,
		StatusDurationMultiplier = 0.6,
	},
}

-- Weak-point / hit-region multipliers. Authored geometry supplies the region
-- name via the HitRegion contract attribute; unknown regions fall back to Body.
Balance.HitRegions = {
	Head = 2.0,
	Body = 1.0,
	Limb = 0.75,
	WeakPoint = 3.0,
	Armored = 0.35,
}

Balance.Limits = {
	MaxDamagePerHit = 5000,
	MaxTriggerDepth = 3, -- stops OnHit -> explosion -> OnHit recursion (§C7)
	MaxSimultaneousProjectiles = 900, -- server-evaluated
	MaxVisualProjectiles = 1200, -- client-rendered
	MaxActiveEnemiesPerPlayer = 12,
	MaxDamageNumbersOnScreen = 48,
}

table.freeze(Balance)
return Balance
