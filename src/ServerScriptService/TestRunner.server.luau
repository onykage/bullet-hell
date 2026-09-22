--!strict
--[[
	TestRunner.server.luau

	Runs the unit specs on every Studio play-test, and in a published build when
	Workspace has a `RunTests` attribute set.

	Tests run in-engine deliberately: the pure modules under test use Vector3,
	CFrame and Random, and a headless shim of those types would drift from the
	real engine. Seeing the result line on every play-test is also what keeps
	the specs honest — a suite nobody runs is documentation, not a test.
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() and Workspace:GetAttribute("RunTests") ~= true then
	return
end

local testsFolder = ServerScriptService:FindFirstChild("Tests")
if not testsFolder then
	return
end

task.defer(function()
	local Tests = require(testsFolder)
	local startedAt = os.clock()
	local passed, failed = Tests.run(testsFolder:GetChildren())
	local elapsed = (os.clock() - startedAt) * 1000

	if failed > 0 then
		warn(string.format("[Tests] %d passed, %d FAILED in %.0f ms", passed, failed, elapsed))
	else
		print(string.format("[Tests] %d passed in %.0f ms", passed, elapsed))
	end
end)
