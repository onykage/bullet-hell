--!strict
--[[
	ClientBootstrap.client.luau

	Client controller startup (§C3).

	Same two-pass contract as the server: every controller Inits before any
	controller Starts. Controllers own presentation and input only — none of
	them decides damage, ammunition, or rewards (§12.1).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

if _G.__BULLET_HELL_CLIENT_STARTED then
	return
end
_G.__BULLET_HELL_CLIENT_STARTED = true

local CONTROLLER_ORDER = {
	"InputController",
	"CameraController",
	"EffectsController",
	"HUDController",
	"DamageNumberController",
	"ProjectileController",
	"MovementController",
	"WeaponController",
}

local controllersFolder = script.Parent:WaitForChild("Controllers")
local controllers: { [string]: any } = {}
local ordered: { any } = {}

for _, name in CONTROLLER_ORDER do
	local module = controllersFolder:FindFirstChild(name)
	assert(module, `[ClientBootstrap] controller {name} missing`)

	local controller = require(module)
	controller.Name = name
	controllers[name] = controller
	table.insert(ordered, controller)
end

local context = {
	controllers = controllers,
	player = Players.LocalPlayer,
	shared = Shared,
}

for _, controller in ordered do
	if controller.Init then
		local ok, err = pcall(controller.Init, controller, context)
		if not ok then
			error(`[ClientBootstrap] {controller.Name}:Init failed: {err}`, 0)
		end
	end
end

for _, controller in ordered do
	if controller.Start then
		local ok, err = pcall(controller.Start, controller, context)
		if not ok then
			error(`[ClientBootstrap] {controller.Name}:Start failed: {err}`, 0)
		end
	end
end

print(`[ClientBootstrap] {#ordered} controllers started`)
