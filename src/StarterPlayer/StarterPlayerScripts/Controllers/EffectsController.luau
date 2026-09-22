--!strict
--[[
	EffectsController.luau

	Pooled tracers, impacts, and muzzle flashes (§16.3).

	Every visual here is created once and reused. During a four-player fight
	against a bullet-hell boss this controller is the busiest thing on the
	client, and Instance.new/Destroy churn at that rate is the classic way to
	lose frame time on mobile.

	Effects live in Workspace under a code-owned folder and are never
	query-able or touchable, so they cannot interfere with raycasts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Pool = require(Shared.Utility.Pool)

local TRACER_LIFETIME = 0.06
local IMPACT_LIFETIME = 0.35

local EffectsController = {}

local function decorate(part: Part)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.CollisionGroup = Contract.CollisionGroups.Projectile
end

function EffectsController:Init()
	self.container = Instance.new("Folder")
	self.container.Name = "ClientEffects"
	self.container.Parent = Workspace

	self.active = {} :: { { part: Part, expiresAt: number, pool: any, fade: boolean } }

	self.tracerPool = Pool.new(function()
		local part = Instance.new("Part")
		part.Name = "Tracer"
		part.Size = Vector3.new(0.12, 0.12, 1)
		decorate(part)
		part.Parent = self.container
		return part
	end, function(part)
		part.Transparency = 1
	end, 48)

	self.impactPool = Pool.new(function()
		local part = Instance.new("Part")
		part.Name = "Impact"
		part.Size = Vector3.new(0.6, 0.6, 0.6)
		part.Shape = Enum.PartType.Ball
		decorate(part)
		part.Parent = self.container
		return part
	end, function(part)
		part.Transparency = 1
	end, 32)

	self.flash = Instance.new("Part")
	self.flash.Name = "MuzzleFlash"
	self.flash.Size = Vector3.new(0.5, 0.5, 0.5)
	self.flash.Shape = Enum.PartType.Ball
	decorate(self.flash)
	self.flash.Transparency = 1
	self.flash.Parent = self.container
	self.flashUntil = 0
end

function EffectsController:Start()
	RunService.RenderStepped:Connect(function()
		self:_update()
	end)
end

function EffectsController:SpawnTracer(origin: Vector3, endpoint: Vector3, color: Color3?)
	local distance = (endpoint - origin).Magnitude
	if distance < 0.5 then
		return
	end

	local part = self.tracerPool:Get()
	part.Size = Vector3.new(0.12, 0.12, distance)
	part.CFrame = CFrame.lookAt(origin, endpoint) * CFrame.new(0, 0, -distance * 0.5)
	part.Color = color or Color3.fromRGB(255, 220, 150)
	part.Transparency = 0.25

	table.insert(self.active, {
		part = part,
		expiresAt = os.clock() + TRACER_LIFETIME,
		pool = self.tracerPool,
		fade = true,
	})
end

function EffectsController:SpawnImpact(position: Vector3, normal: Vector3)
	local part = self.impactPool:Get()
	part.CFrame = CFrame.new(position + normal * 0.1)
	part.Color = Color3.fromRGB(255, 200, 140)
	part.Transparency = 0.15
	part.Size = Vector3.new(0.6, 0.6, 0.6)

	table.insert(self.active, {
		part = part,
		expiresAt = os.clock() + IMPACT_LIFETIME,
		pool = self.impactPool,
		fade = true,
	})
end

function EffectsController:MuzzleFlash(position: Vector3?)
	if not position then
		return
	end
	self.flash.Position = position
	self.flash.Color = Color3.fromRGB(255, 226, 170)
	self.flash.Transparency = 0.1
	self.flashUntil = os.clock() + 0.04
end

function EffectsController:_update()
	local now = os.clock()

	if self.flash.Transparency < 1 and now > self.flashUntil then
		self.flash.Transparency = 1
	end

	for index = #self.active, 1, -1 do
		local record = self.active[index]
		if now >= record.expiresAt then
			record.pool:Release(record.part)
			table.remove(self.active, index)
		elseif record.fade then
			local remaining = record.expiresAt - now
			record.part.Transparency = 1 - math.clamp(remaining * 8, 0, 0.85)
		end
	end
end

return EffectsController
