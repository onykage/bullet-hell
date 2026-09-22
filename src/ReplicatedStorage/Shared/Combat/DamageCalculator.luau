--!strict
--[[
	Combat/DamageCalculator.luau

	The single auditable damage path (§C7). Every damage source in the game —
	bullets, pellets, boss projectiles, enemy melee, explosions — resolves
	through `resolve`. Nothing subtracts health anywhere else.

	Calculation order is fixed and documented (§8.5):

	    base
	    -> flat additions
	    -> additive percentages
	    -> multiplicative modifiers
	    -> hit region
	    -> distance falloff
	    -> critical
	    -> PvE/PvP profile
	    -> caps
]]

local Balance = require(script.Parent.Parent.Config.Balance)
local Types = require(script.Parent.Parent.Types)

type DamageContext = Types.DamageContext
type DamageResult = Types.DamageResult

local DamageCalculator = {}

export type Modifiers = {
	flat: number?,
	additivePercent: number?, -- 0.15 == +15%
	multiplicative: number?, -- applied as a product
	falloff: number?,
	regionMultiplier: number?,
}

--[[
	Pure. Returns the final damage number for a context plus modifiers.
	No instance access, so it is unit-testable without a running game.
]]
function DamageCalculator.compute(context: DamageContext, modifiers: Modifiers?): number
	local mods = modifiers or {}
	local damage = context.baseDamage

	damage += mods.flat or 0
	damage *= 1 + (mods.additivePercent or 0)
	damage *= mods.multiplicative or 1
	damage *= mods.regionMultiplier or 1
	damage *= mods.falloff or 1

	if context.isCritical then
		local profile = if context.isPvP then Balance.Profiles.PvP else Balance.Profiles.PvE
		-- The weapon's own crit multiplier is folded in by the caller via
		-- `multiplicative`; this is the mode-level scaling on top of it.
		damage *= profile.CriticalMultiplier
	end

	local profile = if context.isPvP then Balance.Profiles.PvP else Balance.Profiles.PvE
	damage *= profile.DamageMultiplier

	damage = math.clamp(damage, 0, Balance.Limits.MaxDamagePerHit)
	return damage
end

--[[
	Resolves the region multiplier for a hit part, using the Studio contract
	attribute when present and falling back to a named region.
]]
function DamageCalculator.regionMultiplier(regionName: string?, explicitMultiplier: number?): number
	if explicitMultiplier then
		-- Authored values are bounded so a mis-set attribute cannot one-shot.
		return math.clamp(explicitMultiplier, 0, Balance.HitRegions.WeakPoint)
	end
	if regionName and Balance.HitRegions[regionName] then
		return Balance.HitRegions[regionName]
	end
	return Balance.HitRegions.Body
end

return DamageCalculator
