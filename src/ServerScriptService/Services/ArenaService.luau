--!strict
--[[
	ArenaService.luau

	Arena entry, encounter start, and return (§C13, §12.5).

	Milestone 1 uses the local Studio fallback the scaffold asks for: the arena
	is a physical space in the same place and entry is a CFrame move, not a
	teleport. Reserved servers need published place IDs, which belong to the
	Studio workstream (§R1) — building against them now would make the slice
	untestable until that handoff lands. The entry/exit flow is already
	structured as a transaction so swapping in TeleportService touches only
	`_enter` and `_return`.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contract = require(Shared.Contract)
local Events = require(Shared.Network.Events)
local StormEngine = require(Shared.Config.Bosses.StormEngine)

local ENTRY_CHECK_INTERVAL = 0.35
local ENTRY_RADIUS = 14

local ArenaService = {}

function ArenaService:Init(context)
	self.boss = context.services.BossService
	self.world = context.services.WorldBuilderService
	self.combat = context.services.CombatService
	self.inArena = {} :: { [Player]: boolean }
	self.accumulator = 0
	self.locked = false
end

function ArenaService:Start()
	self.stateRemote = Events.get("S2C_ArenaState")
	self.requestRemote = Events.get("C2S_ArenaRequest")

	self.boss.EncounterEnded:Connect(function(victory: boolean)
		self:_returnAll(victory)
	end)

	self.requestRemote.OnServerEvent:Connect(function(player, action)
		-- The only client-initiated arena action in the slice is "leave".
		-- Entry is decided by the server from world position, never by request.
		if action == "Leave" and self.inArena[player] then
			self:_returnPlayer(player, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.inArena[player] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		self.accumulator += deltaTime
		if self.accumulator < ENTRY_CHECK_INTERVAL then
			return
		end
		self.accumulator = 0
		self:_checkEntrances()
	end)
end

function ArenaService:_checkEntrances()
	if self.locked or self.boss:IsActive() then
		return
	end

	for _, entrance in CollectionService:GetTagged(Contract.Tags.ArenaEntrance) do
		if not entrance:IsA("BasePart") then
			continue
		end
		if entrance:GetAttribute("ArenaId") ~= StormEngine.ArenaId then
			continue
		end

		local waiting: { Player } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or self.inArena[player] then
				continue
			end
			if (root.Position - (entrance :: BasePart).Position).Magnitude <= ENTRY_RADIUS then
				table.insert(waiting, player)
			end
		end

		if #waiting > 0 then
			self:_enter(waiting)
			return
		end
	end
end

--[[
	Moves a party into the arena and starts the encounter.

	Locked for the duration so a player stepping on the pad mid-encounter
	cannot start a second boss or be dropped into a running fight.
]]
function ArenaService:_enter(party: { Player })
	local spawns = {}
	for _, instance in CollectionService:GetTagged(Contract.Tags.PlayerSpawn) do
		if instance:GetAttribute("SpawnType") == "Arena" then
			table.insert(spawns, instance)
		end
	end

	if #spawns == 0 then
		warn("[ArenaService] no arena spawns found; refusing entry")
		return
	end

	self.locked = true

	for index, player in party do
		local character = player.Character
		if not character or not character.PrimaryPart then
			continue
		end

		local spawn = spawns[((index - 1) % #spawns) + 1]
		character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, 5, 0)))
		self.inArena[player] = true
	end

	local started = self.boss:StartEncounter(party)
	if not started then
		self.locked = false
		return
	end

	self.stateRemote:FireAllClients({ state = "Entered", arenaId = StormEngine.ArenaId, partySize = #party })
end

function ArenaService:_returnPlayer(player: Player, victory: boolean)
	self.inArena[player] = nil

	local hubSpawn = self.world.hubSpawn
	local character = player.Character
	if character and character.PrimaryPart and hubSpawn then
		character:PivotTo(CFrame.new(hubSpawn.Position + Vector3.new(0, 5, 0)))
	end

	self.stateRemote:FireClient(player, { state = "Returned", victory = victory })
end

function ArenaService:_returnAll(victory: boolean)
	for player in self.inArena do
		self:_returnPlayer(player, victory)
	end
	table.clear(self.inArena)

	-- A short lock after the encounter prevents an instant re-entry loop while
	-- the boss is still cleaning up.
	task.delay(3, function()
		self.locked = false
	end)
end

return ArenaService
