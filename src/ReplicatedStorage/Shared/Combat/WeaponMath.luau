--!strict
--[[
	Combat/WeaponMath.luau

	Pure weapon math shared by the client (predicting where a shot goes, drawing
	the crosshair) and the server (validating that the client's claimed
	direction was possible).

	Shared, not duplicated: if the client's spread cone and the server's spread
	cone disagreed, either honest players get rejected or cheaters get through.
]]

local Types = require(script.Parent.Parent.Types)

type WeaponStats = Types.WeaponStats

local WeaponMath = {}

--[[
	Current spread cone half-angle in degrees, given accumulated bloom.
]]
function WeaponMath.currentSpread(stats: WeaponStats, bloom: number, isAiming: boolean): number
	local base = if isAiming then stats.AimSpreadDegrees else stats.SpreadDegrees
	return base + math.max(0, bloom)
end

--[[
	Bloom decay between shots.
]]
function WeaponMath.decayBloom(stats: WeaponStats, bloom: number, deltaTime: number): number
	return math.max(0, bloom - stats.SpreadRecovery * deltaTime)
end

function WeaponMath.addBloom(stats: WeaponStats, bloom: number): number
	local ceiling = stats.SpreadDegrees * 3
	return math.min(ceiling, bloom + stats.SpreadPerShot)
end

--[[
	Deterministically scatters a direction inside a cone. Seeded so the server
	can reproduce the client's pellet spread for a given shot when auditing.
]]
function WeaponMath.applySpread(direction: Vector3, spreadDegrees: number, rng: Random): Vector3
	if spreadDegrees <= 0 then
		return direction.Unit
	end

	-- Uniform over the spherical cap, not over the angle: sampling the angle
	-- directly clusters pellets at the centre and makes shotguns feel tighter
	-- than their stated spread.
	local maxCos = math.cos(math.rad(spreadDegrees))
	local z = rng:NextNumber(maxCos, 1)
	local phi = rng:NextNumber(0, 2 * math.pi)
	local sinTheta = math.sqrt(math.max(0, 1 - z * z))

	local forward = direction.Unit
	local reference = if math.abs(forward.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local right = forward:Cross(reference).Unit
	local up = right:Cross(forward).Unit

	return (forward * z + right * (sinTheta * math.cos(phi)) + up * (sinTheta * math.sin(phi))).Unit
end

--[[
	Distance damage falloff multiplier.
]]
function WeaponMath.falloffMultiplier(stats: WeaponStats, distance: number): number
	if distance <= stats.FalloffStart then
		return 1
	end
	if distance >= stats.Range then
		return stats.FalloffMinimum
	end

	local span = stats.Range - stats.FalloffStart
	if span <= 0 then
		return stats.FalloffMinimum
	end

	local alpha = (distance - stats.FalloffStart) / span
	return 1 + (stats.FalloffMinimum - 1) * alpha
end

--[[
	Minimum legal seconds between shots, with a tolerance for network jitter.
	The server uses this to reject impossible fire rates (§15.1) without
	punishing a player whose packets bunched up.
]]
function WeaponMath.minimumShotInterval(stats: WeaponStats, tolerance: number?): number
	local interval = 1 / math.max(stats.FireRate, 0.001)
	return interval * (1 - (tolerance or 0.12))
end

--[[
	Widest angle a shot may legally deviate from the player's reported aim.
	Used server-side: a client claiming a direction outside its own weapon's
	cone is either desynced or lying.
]]
function WeaponMath.maximumLegalDeviation(stats: WeaponStats): number
	-- Hip spread + full bloom ceiling + a margin for camera interpolation.
	return stats.SpreadDegrees * 3 + stats.SpreadPerShot + 6
end

return WeaponMath
