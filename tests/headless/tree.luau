--!nocheck
--[[
	tests/headless/tree.luau

	Mirrors the on-disk src/ tree into REAL Roblox Instances (Lune's
	implementation), with each script's Source read from the file.

	Real Instances rather than lookalike tables, because everything downstream
	then works for free: `Shared.Combat.DamageCalculator` indexes a child,
	`script.Parent.Parent` walks up, `script:GetChildren()` feeds the content
	registries, `module:IsA("ModuleScript")` is true, and instances can be
	parented into the DataModel.

	Directory rules match Rojo's:
	  * a folder containing init.luau BECOMES that ModuleScript, and the
	    folder's other entries become its children
	  * Name.server.luau / Name.client.luau are Scripts named "Name"
	  * everything else .luau is a ModuleScript
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Tree = {}

local function scriptNameOf(fileName: string): (string, string)
	local base = string.gsub(fileName, "%.luau$", "")
	local stripped = string.gsub(string.gsub(base, "%.server$", ""), "%.client$", "")
	local isScript = string.match(base, "%.server$") or string.match(base, "%.client$")
	return stripped, if isScript then "Script" else "ModuleScript"
end

--[[
	Builds an Instance for a directory and everything under it.
	`transform` is applied to every script's source before it is stored.
]]
function Tree.fromDirectory(path: string, name: string, transform: ((string) -> string)?)
	local entries = fs.readDir(path)
	table.sort(entries)

	local initPath = nil
	for _, entry in entries do
		if entry == "init.luau" then
			initPath = `{path}/init.luau`
		end
	end

	local container
	if initPath then
		container = roblox.Instance.new("ModuleScript")
		local source = fs.readFile(initPath)
		container.Source = if transform then transform(source) else source
	else
		container = roblox.Instance.new("Folder")
	end
	container.Name = name

	for _, entry in entries do
		local full = `{path}/{entry}`

		if fs.isDir(full) then
			local child = Tree.fromDirectory(full, entry, transform)
			child.Parent = container
		elseif string.match(entry, "%.luau$") and entry ~= "init.luau" then
			local childName, className = scriptNameOf(entry)
			local child = roblox.Instance.new(className)
			child.Name = childName
			local source = fs.readFile(full)
			child.Source = if transform then transform(source) else source
			child.Parent = container
		end
	end

	return container
end

return Tree
