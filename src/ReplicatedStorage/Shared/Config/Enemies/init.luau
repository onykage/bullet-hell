--!strict
--[[
	Config/Enemies — the milestone-1 enemy set.

	Three standard archetypes plus a static dummy for weapon-feel testing.
	Roles follow §5.3; each exists to make a different weapon choice correct.
]]

local Enemies = {}

local definitions = {
	target_dummy = {
		Id = "target_dummy",
		DisplayName = "Target Dummy",
		Role = "Dummy",
		Health = 100000, -- effectively unkillable; it is a measuring device
		WalkSpeed = 0,
		Damage = 0,
		AttackRange = 0,
		AttackCooldown = math.huge,
		Color = Color3.fromRGB(196, 168, 92),
		Size = Vector3.new(3, 6, 3),
		ResetHealthAfter = 3.0, -- lets you read a full DPS window repeatedly
		XP = 0,
	},

	frontier_grunt = {
		Id = "frontier_grunt",
		DisplayName = "Frontier Grunt",
		Role = "Grunt",
		Health = 120,
		WalkSpeed = 13,
		Damage = 8,
		AttackRange = 60,
		AttackCooldown = 1.4,
		Color = Color3.fromRGB(150, 70, 62),
		Size = Vector3.new(3, 5.5, 3),
		XP = 12,
	},

	scrap_rusher = {
		Id = "scrap_rusher",
		DisplayName = "Scrap Rusher",
		Role = "Rusher",
		Health = 80,
		WalkSpeed = 26,
		Damage = 16,
		AttackRange = 7,
		AttackCooldown = 1.0,
		Color = Color3.fromRGB(206, 108, 48),
		Size = Vector3.new(2.6, 4.6, 2.6),
		XP = 16,
	},

	arc_marksman = {
		Id = "arc_marksman",
		DisplayName = "Arc Marksman",
		Role = "Marksman",
		Health = 95,
		WalkSpeed = 9,
		Damage = 22,
		AttackRange = 170,
		AttackCooldown = 2.6,
		Color = Color3.fromRGB(96, 132, 196),
		Size = Vector3.new(2.8, 5.8, 2.8),
		XP = 20,
	},
}

function Enemies.get(id: string): any?
	return definitions[id]
end

function Enemies.expect(id: string): any
	local definition = definitions[id]
	assert(definition, `[Enemies] unknown enemy id {id}`)
	return definition
end

function Enemies.all()
	return table.clone(definitions)
end

return Enemies
