--!strict
--[[
	PlayerDataService.luau

	Milestone 1: an in-memory profile store with the real API shape.

	Deliberately NOT backed by DataStores yet. The scaffold (§C15) requires
	versioned schemas, session locking, and idempotent transactions before
	anything touches live data, and a half-done persistence layer is the one
	kind of bug that destroys player trust. Until that milestone lands, profiles
	live for the session only — but every caller already goes through this
	interface, so swapping the backend touches this file and nothing else.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)

local SCHEMA_VERSION = 1

export type Profile = {
	SchemaVersion: number,
	Progression: { Level: number, Experience: number },
	Loadout: { string },
	EquippedIndex: number,
	Statistics: { [string]: number },
}

local PlayerDataService = {}

local function newProfile(): Profile
	return {
		SchemaVersion = SCHEMA_VERSION,
		Progression = { Level = 1, Experience = 0 },
		Loadout = table.clone(Weapons.DefaultLoadout),
		EquippedIndex = 1,
		Statistics = { ShotsFired = 0, DamageDealt = 0, Kills = 0, Deaths = 0 },
	}
end

function PlayerDataService:Init()
	self.profiles = {} :: { [number]: Profile }
	self.loaded = {} :: { [number]: boolean }
end

function PlayerDataService:Start()
	local function onAdded(player: Player)
		self.profiles[player.UserId] = newProfile()
		self.loaded[player.UserId] = true
	end

	for _, player in Players:GetPlayers() do
		onAdded(player)
	end
	Players.PlayerAdded:Connect(onAdded)

	Players.PlayerRemoving:Connect(function(player)
		self.profiles[player.UserId] = nil
		self.loaded[player.UserId] = nil
	end)
end

--[[
	Returns nil while a profile is still loading. Callers must treat nil as
	"block the mutation", never as "use defaults" (§C15): silently defaulting is
	how a failed load turns into an erased inventory.
]]
function PlayerDataService:GetProfile(player: Player): Profile?
	if not self.loaded[player.UserId] then
		return nil
	end
	return self.profiles[player.UserId]
end

function PlayerDataService:IncrementStat(player: Player, stat: string, amount: number)
	local profile = self:GetProfile(player)
	if not profile then
		return
	end
	profile.Statistics[stat] = (profile.Statistics[stat] or 0) + amount
end

function PlayerDataService:GetLoadout(player: Player): { string }
	local profile = self:GetProfile(player)
	return if profile then table.clone(profile.Loadout) else {}
end

--[[
	Server-side authority over what the player may equip. A client asking to
	equip a weapon that is not in its own loadout is refused here (§15.1).
]]
function PlayerDataService:CanEquip(player: Player, weaponId: string): boolean
	local profile = self:GetProfile(player)
	if not profile then
		return false
	end
	return table.find(profile.Loadout, weaponId) ~= nil
end

return PlayerDataService
