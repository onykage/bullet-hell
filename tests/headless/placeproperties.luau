--!nocheck
--[[
	tests/headless/placeproperties.luau

	Guards against writing place properties from a script at runtime.

	Roblox sandboxes a class of properties so that only Studio or a plugin may
	write them. A script that tries gets:

	    the current thread cannot write 'X' (lacking capability plugin)

	That throw cost us the entire world once: `Workspace.FallenPartsDestroyHeight
	= -500` was the first line of WorldBuilderService:Start, it threw, Start
	never reached the geometry, and players fell through an empty place.

	Neither Lune nor Luau's type checker models this — Lune happily accepts the
	write — so it is checked statically here instead.

	THE RULE: anything set in default.project.json's `$properties` is a place
	property. Configure it there; never assign it from a script. The list is
	derived from the project file itself, so it stays correct as the project
	changes, plus a short explicit list of properties we do not currently set
	but which are restricted all the same.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PlaceProperties = {}

-- Restricted whether or not we set them in the project file.
local ALWAYS_RESTRICTED = {
	"FallenPartsDestroyHeight",
	"StreamingEnabled",
	"StreamingMinRadius",
	"StreamingTargetRadius",
	"StreamingIntegrityMode",
	"Technology",
	"AllowThirdPartySales",
	"SignalBehavior",
	"MeshPartHeadsAndAccessories",
}

--[[
	Collects every property name configured under a `$properties` block, at any
	depth of the project tree.
]]
local function collectConfigured(node: any, into: { [string]: boolean })
	if typeof(node) ~= "table" then
		return
	end

	for key, value in node do
		if key == "$properties" and typeof(value) == "table" then
			for propertyName in value do
				into[propertyName] = true
			end
		elseif typeof(value) == "table" then
			collectConfigured(value, into)
		end
	end
end

local function listLuauFiles(directory: string, into: { string })
	for _, entry in fs.readDir(directory) do
		local path = `{directory}/{entry}`
		if fs.isDir(path) then
			listLuauFiles(path, into)
		elseif string.match(entry, "%.luau$") then
			table.insert(into, path)
		end
	end
	return into
end

--[[
	Returns a list of violations: { path, line, property, text }.
]]
function PlaceProperties.scan(root: string)
	local project = serde.decode("json", fs.readFile(`{root}/default.project.json`))

	local restricted = {}
	for _, name in ALWAYS_RESTRICTED do
		restricted[name] = true
	end
	collectConfigured(project.tree, restricted)

	local files = listLuauFiles(`{root}/src`, {})

	local violations = {}
	for _, path in files do
		local lineNumber = 0
		for line in string.gmatch(fs.readFile(path) .. "\n", "([^\n]*)\n") do
			lineNumber += 1

			-- Comments describe the rule; they do not break it.
			local code = string.match(line, "^%s*%-%-") and "" or line

			for property in pairs(restricted) do
				-- `something.Property =` but not `==`, and not a read.
				local pattern = `[%w_%]%)]%.{property}%s*=[^=]`
				if string.find(code, pattern) then
					table.insert(violations, {
						-- Plain prefix removal: the repo path may contain Lua
						-- pattern magic characters such as "-".
						path = string.sub(path, #root + 2),
						line = lineNumber,
						property = property,
						text = string.match(line, "^%s*(.-)%s*$"),
					})
				end
			end
		end
	end

	return violations, restricted
end

return PlaceProperties
