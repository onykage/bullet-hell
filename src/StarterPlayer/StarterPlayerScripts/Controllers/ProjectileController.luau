--!strict
--[[
	ProjectileController.luau

	Renders boss bullet patterns from the compact spawn records the server
	sends (§16.1).

	The server never tells this controller where a projectile IS. It sends the
	pattern id, seed, start time, origin and target once; this controller
	expands that through the SAME pure module the server hit-tests with, then
	draws the result every frame from a pool. Hundreds of projectiles cost one
	remote call and zero per-frame network traffic.

	Readability rules from §7.4 are enforced here, not left to content:
	  * the drawn ball is larger than the damaging radius, so a graze reads as
	    a miss rather than as an unexplained hit
	  * a telegraph plays before damage becomes active
	  * pattern colour comes from the shared definition, so the friendly /
	    hostile / unblockable language stays consistent
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Contract = require(Shared.Contract)
local Events = require(Shared.Network.Events)
local Pool = require(Shared.Utility.Pool)
local ProjectilePattern = require(Shared.Combat.ProjectilePattern)
local StormEngine = require(Shared.Config.Bosses.StormEngine)

local ProjectileController = {}

type Active = {
	instanceId: number,
	definition: any,
	spawn: any,
	shots: { ProjectilePattern.Shot },
	parts: { [number]: Part },
	telegraph: Part?,
}

function ProjectileController:Init()
	self.container = Instance.new("Folder")
	self.container.Name = "ClientProjectiles"
	self.container.Parent = Workspace

	self.active = {} :: { [number]: Active }

	self.pool = Pool.new(function()
		local part = Instance.new("Part")
		part.Name = "Projectile"
		part.Shape = Enum.PartType.Ball
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.CollisionGroup = Contract.CollisionGroups.Projectile
		part.Transparency = 1
		part.Parent = self.container
		return part
	end, function(part)
		part.Transparency = 1
	end, 160, Balance.Limits.MaxVisualProjectiles)
end

function ProjectileController:Start()
	self.spawnRemote = Events.get("S2C_PatternSpawn")
	self.cancelRemote = Events.get("S2C_PatternCancelled")

	self.spawnRemote.OnClientEvent:Connect(function(spawn, speedScale: number)
		self:_onPatternSpawn(spawn, speedScale)
	end)

	self.cancelRemote.OnClientEvent:Connect(function(instanceId: number)
		self:_release(instanceId)
	end)

	RunService.RenderStepped:Connect(function()
		self:_update()
	end)
end

function ProjectileController:_onPatternSpawn(spawn: any, speedScale: number)
	local base = StormEngine.Patterns[spawn.patternId]
	if not base then
		warn(`[ProjectileController] unknown pattern {tostring(spawn.patternId)}`)
		return
	end

	-- Reproduce exactly the definition the server used, including the enrage
	-- speed scaling, or the two sides would disagree about positions.
	local definition = table.clone(base)
	definition.Speed = base.Speed * (speedScale or 1)
	definition.RotationSpeed = (base.RotationSpeed or 0) * (speedScale or 1)

	local shots = ProjectilePattern.build(definition, spawn)

	local active: Active = {
		instanceId = spawn.instanceId,
		definition = definition,
		spawn = spawn,
		shots = shots,
		parts = {},
		telegraph = nil,
	}

	self.active[spawn.instanceId] = active
	self:_spawnTelegraph(active)
end

--[[
	The telegraph is a ground marker shown for TelegraphTime before the first
	projectile becomes damaging. It is the contract with the player: nothing
	hurts you that you were not warned about (§7.4).
]]
function ProjectileController:_spawnTelegraph(active: Active)
	local definition = active.definition
	if definition.TelegraphTime <= 0 then
		return
	end

	local marker = Instance.new("Part")
	marker.Name = "Telegraph"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = definition.Color
	marker.Transparency = 0.75
	marker.Shape = Enum.PartType.Cylinder
	marker.CollisionGroup = Contract.CollisionGroups.Projectile

	local radius = if definition.Kind == "Orbit" then (definition.OrbitRadius or 20) else 26
	marker.Size = Vector3.new(0.2, radius * 2, radius * 2)
	marker.CFrame = CFrame.new(active.spawn.origin.Position * Vector3.new(1, 0, 1) + Vector3.new(0, 0.3, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = self.container

	active.telegraph = marker

	task.delay(definition.TelegraphTime, function()
		if marker.Parent then
			marker:Destroy()
		end
		if active.telegraph == marker then
			active.telegraph = nil
		end
	end)
end

function ProjectileController:_update()
	local now = Workspace:GetServerTimeNow()

	for instanceId, active in self.active do
		local elapsed = now - active.spawn.startTime
		local definition = active.definition

		if ProjectilePattern.isFinished(active.shots, definition, elapsed) then
			self:_release(instanceId)
			continue
		end

		for index, shot in active.shots do
			local position = ProjectilePattern.positionAt(shot, definition, elapsed)
			local part = active.parts[index]

			if not position then
				if part then
					self.pool:Release(part)
					active.parts[index] = nil
				end
				continue
			end

			if not part then
				part = self.pool:Get()
				-- Drawn larger than the damaging radius, on purpose.
				local diameter = definition.VisualRadius * 2
				part.Size = Vector3.new(diameter, diameter, diameter)
				part.Color = definition.Color
				part.Transparency = 0.1
				active.parts[index] = part
			end

			part.Position = position
		end
	end
end

function ProjectileController:_release(instanceId: number)
	local active = self.active[instanceId]
	if not active then
		return
	end

	for index, part in active.parts do
		self.pool:Release(part)
		active.parts[index] = nil
	end

	if active.telegraph then
		active.telegraph:Destroy()
	end

	self.active[instanceId] = nil
end

return ProjectileController
