--!strict
--[[
	Config/Weapons — weapon registry.

	Configuration modules hold data, never mutable runtime state (§13).
	The registry rejects duplicate IDs at require time so content collisions
	fail at startup rather than silently shadowing each other (§C2).
]]

local Types = require(script.Parent.Parent.Types)

type WeaponDefinition = Types.WeaponDefinition

local definitions: { [string]: WeaponDefinition } = {}
local order: { string } = {}

for _, module in script:GetChildren() do
	if not module:IsA("ModuleScript") then
		continue
	end

	local definition = require(module) :: WeaponDefinition
	assert(definition.Id, `[Weapons] {module.Name} has no Id`)
	assert(
		definitions[definition.Id] == nil,
		`[Weapons] duplicate weapon Id {definition.Id} (from {module.Name})`
	)
	assert(
		definition.Id == string.lower(definition.Id),
		`[Weapons] Id {definition.Id} must be lower_snake_case`
	)

	definitions[definition.Id] = definition
	table.insert(order, definition.Id)
end

table.sort(order)

local Weapons = {}

function Weapons.get(id: string): WeaponDefinition?
	return definitions[id]
end

function Weapons.expect(id: string): WeaponDefinition
	local definition = definitions[id]
	assert(definition, `[Weapons] unknown weapon id {id}`)
	return definition
end

function Weapons.ids(): { string }
	return table.clone(order)
end

function Weapons.all(): { [string]: WeaponDefinition }
	return table.clone(definitions)
end

--[[
	Milestone 1 starting loadout. Replaced by PlayerDataService profiles once
	persistence lands (§C15); kept here so the slice is playable with no
	DataStore access in Studio.
]]
Weapons.DefaultLoadout =
	{ "frontier_rifle", "breaker_shotgun", "sidearm_pistol", "ripper_smg", "longshot_sniper" }

return Weapons
