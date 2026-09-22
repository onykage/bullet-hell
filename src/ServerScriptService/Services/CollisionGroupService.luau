--!strict
--[[
	CollisionGroupService.luau

	Registers the collision groups named in the shared Contract (§R2) and wires
	the interactions code depends on.

	Registering them here rather than in Studio means the place file and the
	code cannot disagree about which groups exist — a mismatch that otherwise
	surfaces as projectiles silently passing through walls.
]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)

local CollisionGroupService = {}

function CollisionGroupService:Init()
	for _, groupName in Contract.CollisionGroups do
		local ok = pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, groupName)
		if not ok then
			-- Already registered (e.g. a re-run in Studio). Not an error.
			continue
		end
	end

	local groups = Contract.CollisionGroups

	-- Players do not collide with each other: bodies blocking doorways during a
	-- four-player bullet-hell fight is a readability problem, not a feature.
	PhysicsService:CollisionGroupSetCollidable(groups.Player, groups.Player, false)

	-- Cosmetic-only categories never push anything around.
	PhysicsService:CollisionGroupSetCollidable(groups.Projectile, groups.Player, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Projectile, groups.Enemy, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Projectile, groups.Projectile, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Projectile, groups.WorldProp, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Viewmodel, groups.Default, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Viewmodel, groups.Player, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Viewmodel, groups.Enemy, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Viewmodel, groups.WorldProp, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Debris, groups.Player, false)
	PhysicsService:CollisionGroupSetCollidable(groups.Debris, groups.Enemy, false)

	-- Enemies collide with the world and with players, but not each other, so
	-- a crowd cannot wedge itself in an arena doorway.
	PhysicsService:CollisionGroupSetCollidable(groups.Enemy, groups.Enemy, false)
end

return CollisionGroupService
