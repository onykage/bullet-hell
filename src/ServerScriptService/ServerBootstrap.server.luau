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

for _, service in ordered do
	if service.Init then
		local ok, err = pcall(service.Init, service, context)
		if not ok then
			error(`[Bootstrap] {service.Name}:Init failed: {err}`, 0)
		end
	end
end

for _, service in ordered do
	if service.Start then
		local ok, err = pcall(service.Start, service, context)
		if not ok then
			error(`[Bootstrap] {service.Name}:Start failed: {err}`, 0)
		end
	end
end

print(string.format("[Bootstrap] %d services started in %.0f ms", #ordered, (os.clock() - START_TIME) * 1000))
