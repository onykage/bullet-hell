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
	local registered = {}

	for key, groupName in Contract.CollisionGroups do
		-- "Default" always exists, so registering it always throws. Other
		-- failures mean the group is genuinely unavailable.
		local ok = pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, groupName)
		registered[key] = ok or groupName == Contract.CollisionGroups.Default
		if not registered[key] then
			warn(`[CollisionGroups] could not register {groupName}; rules involving it are skipped`)
		end
	end

	local groups = Contract.CollisionGroups

	--[[
		Every rule is applied through here.

		Previously these were bare calls: one unregistered group made
		CollisionGroupSetCollidable throw, which failed this service's Init,
		which aborted ServerBootstrap — and the entire world silently never
		built. A collision rule is not worth the whole server, so a failure
		warns and the rest continue.
	]]
	local function setCollidable(firstKey: string, secondKey: string, collidable: boolean)
		if not registered[firstKey] or not registered[secondKey] then
			return
		end

		local ok, err = pcall(
			PhysicsService.CollisionGroupSetCollidable,
			PhysicsService,
			groups[firstKey],
			groups[secondKey],
			collidable
		)
		if not ok then
			warn(`[CollisionGroups] {groups[firstKey]} vs {groups[secondKey]} failed: {err}`)
		end
	end

	-- Players do not collide with each other: bodies blocking a doorway during
	-- a four-player bullet-hell fight is a readability problem, not a feature.
	setCollidable("Player", "Player", false)

	-- Cosmetic-only categories never push anything around.
	setCollidable("Projectile", "Player", false)
	setCollidable("Projectile", "Enemy", false)
	setCollidable("Projectile", "Projectile", false)
	setCollidable("Projectile", "WorldProp", false)
	setCollidable("Viewmodel", "Default", false)
	setCollidable("Viewmodel", "Player", false)
	setCollidable("Viewmodel", "Enemy", false)
	setCollidable("Viewmodel", "WorldProp", false)
	setCollidable("Debris", "Player", false)
	setCollidable("Debris", "Enemy", false)

	-- Enemies collide with the world and with players, but not each other, so
	-- a crowd cannot wedge itself in an arena doorway.
	setCollidable("Enemy", "Enemy", false)
end

return CollisionGroupService
