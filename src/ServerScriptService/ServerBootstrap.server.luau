--!strict
--[[
	ServerBootstrap.server.luau

	Deterministic service startup (§C3).

	  1. Remotes are created BEFORE any service runs, so no service can race
	     the creation of the remote it wants to connect.
	  2. Services are required, then Init'd, then Start'd — in that order, in
	     the order listed below. Init may not depend on another service having
	     Started; Start may assume every Init has completed.
	  3. A failure in Init or Start is reported loudly with the service name.
	     A half-initialised server is worse than a server that refuses to boot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Network.Events)

-- Guard against double execution during Studio play-solo edge cases (§C3).
if _G.__BULLET_HELL_SERVER_STARTED then
	warn("[Bootstrap] server bootstrap ran twice; ignoring the second run")
	return
end
_G.__BULLET_HELL_SERVER_STARTED = true

local START_TIME = os.clock()

-- Remotes first. Nothing below may create a remote of its own.
Events.buildAll()

--[[
	Startup order. Dependencies point upward only:
	  CollisionGroups -> WorldBuilder -> PlayerData -> Combat -> Weapon/Movement
	  -> Enemy -> Boss -> Arena
]]
local SERVICE_ORDER = {
	"CollisionGroupService",
	"WorldBuilderService",
	"PlayerDataService",
	"CombatService",
	"WeaponService",
	"MovementService",
	"EnemyService",
	"BossService",
	"ArenaService",
}

local servicesFolder = script.Parent:WaitForChild("Services")
local services: { [string]: any } = {}
local ordered: { any } = {}

for _, name in SERVICE_ORDER do
	local module = servicesFolder:FindFirstChild(name)
	assert(module, `[Bootstrap] service module {name} is missing from Services/`)

	local ok, result = pcall(require, module)
	if not ok then
		ReplicatedStorage:SetAttribute("BootStatus", "Failed")
		ReplicatedStorage:SetAttribute("BootError", `requiring {name}: {result}`)
		error(`[Bootstrap] failed to require {name}: {result}`, 0)
	end

	result.Name = name
	services[name] = result
	table.insert(ordered, result)
end

-- The context table is how services reach each other. No service reaches into
-- another service's internals; it calls declared methods only (§13).
local context = {
	services = services,
	isStudio = RunService:IsStudio(),
}

--[[
	A boot failure used to be invisible: the error landed in the server log, the
	world never built, and the player saw an empty place with no explanation.

	The status is now published to clients as an attribute, so the diagnostics
	overlay can say what broke instead of leaving a blank screen. The failure is
	still fatal — a half-initialised server is worse than one that refuses to
	boot — it is just no longer silent.
]]
local function publish(status: string, detail: string?)
	ReplicatedStorage:SetAttribute("BootStatus", status)
	ReplicatedStorage:SetAttribute("BootError", detail)
end

publish("Starting", nil)

local function runPhase(method: string)
	for _, service in ordered do
		local callback = service[method]
		if not callback then
			continue
		end

		local ok, err = pcall(callback, service, context)
		if not ok then
			local message = `{service.Name}:{method} failed — {err}`
			publish("Failed", message)
			error(`[Bootstrap] {message}`, 0)
		end
	end
end

runPhase("Init")
runPhase("Start")

publish("Ready", nil)

print(string.format("[Bootstrap] %d services started in %.0f ms", #ordered, (os.clock() - START_TIME) * 1000))
