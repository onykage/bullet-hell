--!strict
-- Boss registry. Same duplicate-ID guarantee as the weapon registry (§C2).

local definitions: { [string]: any } = {}

for _, module in script:GetChildren() do
	if not module:IsA("ModuleScript") then
		continue
	end
	local definition = require(module) :: any
	assert(definition.Id, `[Bosses] {module.Name} has no Id`)
	assert(definitions[definition.Id] == nil, `[Bosses] duplicate boss Id {definition.Id}`)
	definitions[definition.Id] = definition
end

local Bosses = {}

function Bosses.get(id: string): any?
	return definitions[id]
end

function Bosses.expect(id: string): any
	local definition = definitions[id]
	assert(definition, `[Bosses] unknown boss id {id}`)
	return definition
end

return Bosses
