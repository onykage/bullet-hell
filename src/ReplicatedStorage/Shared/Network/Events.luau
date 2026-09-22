--!strict
--[[
	Network/Events.luau

	Every remote in the game is declared here (§C4). No gameplay system may
	create a remote ad hoc. The server creates the instances at boot; the client
	waits for them.

	Naming convention:
	  C2S_*  client -> server request  (always validated, always rate limited)
	  S2C_*  server -> client confirmation / state (trusted by the client)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_FOLDER_NAME = "Remotes"

local EVENT_NAMES = {
	-- Weapon
	"C2S_FireWeapon",
	"C2S_ReloadWeapon",
	"C2S_EquipWeapon",
	"S2C_FireConfirmed",
	"S2C_FireRejected",
	"S2C_AmmoChanged",
	"S2C_DamageDealt", -- drives floating damage numbers + hitmarkers
	"S2C_DamageTaken",

	-- Movement
	"C2S_MovementAbility",
	"S2C_MovementResponse",

	-- Combat / health
	"S2C_HealthChanged",
	"S2C_EntityDied",

	-- Boss / patterns
	"S2C_BossState",
	"S2C_PatternSpawn",
	"S2C_PatternCancelled",

	-- Arena
	"C2S_ArenaRequest",
	"S2C_ArenaState",
}

local FUNCTION_NAMES = {
	"C2S_GetLoadout",
}

local Events = {}
local cache: { [string]: Instance } = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = REMOTE_FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end

	return ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME, 30) :: Folder
end

--[[
	Server-only. Called once by ServerBootstrap before any service initialises,
	so that no service can race the creation of its own remote.
]]
function Events.buildAll()
	assert(RunService:IsServer(), "Events.buildAll is server-only")
	local folder = getFolder()

	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	for _, name in FUNCTION_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Events.get(name: string): any
	local cached = cache[name]
	if cached then
		return cached
	end

	local folder = getFolder()
	local remote = folder:FindFirstChild(name) or folder:WaitForChild(name, 30)
	assert(remote, `[Events] remote {name} was never created — is it declared in Events.luau?`)

	cache[name] = remote
	return remote
end

return Events
