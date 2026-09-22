--!strict
--[[
	Network/Schemas.luau

	Payload validation for every client -> server remote (§C4, §15.2).

	Rules enforced here:
	  * unknown fields are rejected, not ignored
	  * every numeric field is finite and within a declared bound
	  * every vector is finite and within world limits
	  * payload nesting depth and array length are capped

	A validator returns (true, cleanedPayload) or (false, reason). The reason is
	for server logs only; clients receive a coarse rejection code so validation
	logic is not leaked to exploiters (§C4).
]]

local Schemas = {}

local MAX_WORLD_COORD = 100_000
local MAX_PELLETS = 16

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteVector(value: any): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	return isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
		and math.abs(value.X) < MAX_WORLD_COORD
		and math.abs(value.Y) < MAX_WORLD_COORD
		and math.abs(value.Z) < MAX_WORLD_COORD
end

local function hasOnlyKeys(payload: { [string]: any }, allowed: { [string]: boolean }): (boolean, string?)
	for key in payload do
		if not allowed[key] then
			return false, `unexpected field {tostring(key)}`
		end
	end
	return true, nil
end

export type FireRequest = {
	sequenceId: number,
	origin: Vector3,
	directions: { Vector3 },
	clientTime: number,
}

local FIRE_KEYS = { sequenceId = true, origin = true, directions = true, clientTime = true }

function Schemas.validateFireRequest(payload: any): (boolean, any)
	if typeof(payload) ~= "table" then
		return false, "payload is not a table"
	end

	local ok, reason = hasOnlyKeys(payload, FIRE_KEYS)
	if not ok then
		return false, reason
	end

	if not isFiniteNumber(payload.sequenceId) or payload.sequenceId < 0 or payload.sequenceId % 1 ~= 0 then
		return false, "sequenceId must be a non-negative integer"
	end

	if not isFiniteVector(payload.origin) then
		return false, "origin is not a finite in-world vector"
	end

	if not isFiniteNumber(payload.clientTime) or payload.clientTime < 0 then
		return false, "clientTime must be a non-negative number"
	end

	if typeof(payload.directions) ~= "table" then
		return false, "directions must be an array"
	end

	local count = #payload.directions
	if count < 1 or count > MAX_PELLETS then
		return false, `directions length {count} outside 1..{MAX_PELLETS}`
	end

	local cleaned = table.create(count)
	for index = 1, count do
		local direction = payload.directions[index]
		if not isFiniteVector(direction) then
			return false, `directions[{index}] is not a finite vector`
		end
		if direction.Magnitude < 0.001 then
			return false, `directions[{index}] has zero magnitude`
		end
		cleaned[index] = direction.Unit
	end

	-- Reject sparse/keyed arrays smuggled in alongside the ordered part.
	local entries = 0
	for _ in payload.directions do
		entries += 1
	end
	if entries ~= count then
		return false, "directions contains non-array entries"
	end

	return true,
		{
			sequenceId = payload.sequenceId,
			origin = payload.origin,
			directions = cleaned,
			clientTime = payload.clientTime,
		}
end

export type MovementRequest = {
	ability: string,
	direction: Vector3,
	clientTime: number,
}

local MOVEMENT_KEYS = { ability = true, direction = true, clientTime = true }
local VALID_ABILITIES = { Slide = true, DoubleJump = true, Dash = true }

function Schemas.validateMovementRequest(payload: any): (boolean, any)
	if typeof(payload) ~= "table" then
		return false, "payload is not a table"
	end

	local ok, reason = hasOnlyKeys(payload, MOVEMENT_KEYS)
	if not ok then
		return false, reason
	end

	if typeof(payload.ability) ~= "string" or not VALID_ABILITIES[payload.ability] then
		return false, "unknown ability"
	end

	if not isFiniteVector(payload.direction) then
		return false, "direction is not a finite vector"
	end

	if not isFiniteNumber(payload.clientTime) or payload.clientTime < 0 then
		return false, "clientTime must be a non-negative number"
	end

	local direction = payload.direction
	if direction.Magnitude > 0.001 then
		direction = direction.Unit
	else
		direction = Vector3.zero
	end

	return true, {
		ability = payload.ability,
		direction = direction,
		clientTime = payload.clientTime,
	}
end

export type EquipRequest = { weaponId: string }

function Schemas.validateEquipRequest(payload: any): (boolean, any)
	if typeof(payload) ~= "table" then
		return false, "payload is not a table"
	end

	local ok, reason = hasOnlyKeys(payload, { weaponId = true })
	if not ok then
		return false, reason
	end

	if typeof(payload.weaponId) ~= "string" or #payload.weaponId == 0 or #payload.weaponId > 64 then
		return false, "weaponId must be a short non-empty string"
	end

	return true, { weaponId = payload.weaponId }
end

-- Coarse codes returned to clients. Never send the detailed reason.
Schemas.RejectionCodes = {
	Malformed = 1,
	RateLimited = 2,
	InvalidState = 3,
	OutOfRange = 4,
	NotPermitted = 5,
	Cooldown = 6,
}

return Schemas
