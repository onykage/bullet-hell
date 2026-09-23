--!nocheck
--[[
	tests/headless/restrictedapi.luau

	Guards against Roblox APIs that a game script is not permitted to use.

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

local RestrictedApi = {}

--[[
	Methods and services that only Studio or a plugin may use. A game script
	calling one throws at runtime, exactly like a restricted property write.

	Instance:GetDebugId is the one that bit us: it was building enemy entity
	ids, so every enemy spawn threw.
]]
local RESTRICTED_CALLS = {
	"GetDebugId",
	"GetObjects",
	"SavePlace",
}

local RESTRICTED_SERVICES = {
	"CoreGui",
	"Selection",
	"ScriptEditorService",
	"StudioService",
	"ChangeHistoryService",
	"PluginGuiService",
}

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
	Returns a list of violations: { path, line, kind, name, text }.
]]
function RestrictedApi.scan(root: string)
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

			-- Plain prefix removal: the repo path may contain Lua pattern
			-- magic characters such as "-".
			local relative = string.sub(path, #root + 2)
			local trimmed = string.match(line, "^%s*(.-)%s*$")

			local function report(kind: string, name: string)
				table.insert(violations, {
					path = relative,
					line = lineNumber,
					kind = kind,
					name = name,
					text = trimmed,
				})
			end

			for property in pairs(restricted) do
				-- `something.Property =` but not `==`, and not a read.
				if string.find(code, `[%w_%]%)]%.{property}%s*=[^=]`) then
					report("writes place property", property)
				end
			end

			for _, method in RESTRICTED_CALLS do
				if string.find(code, `:{method}%s*%(`) then
					report("calls plugin-only method", method)
				end
			end

			for _, service in RESTRICTED_SERVICES do
				if string.find(code, `GetService%("{service}"%)`) then
					report("uses plugin-only service", service)
				end
			end
		end
	end

	return violations, restricted
end

return RestrictedApi
