--!nocheck
--[[
	tests/headless/runtime.luau

	A minimal Roblox server runtime on top of Lune, so the server can be booted
	and inspected on Linux, where Roblox Studio does not exist.

	WHAT THIS CATCHES
	  * runtime errors during service Init/Start — the "nothing loads" class
	  * nil indexing, failed assertions, contract violations
	  * properties and API calls that do not exist
	  * the structure, tagging, and geometry the world builder produces

	WHAT IT CANNOT CATCH, and never will
	  * physics: constraints, collisions, character movement, raycasts
	  * replication, rendering, input, animation
	  * anything that depends on the task scheduler or real time

	It is a boot-and-world-integrity smoke test, not a Roblox emulator. The
	in-engine specs remain the source of truth for behaviour that needs real
	physics. Where this runtime lies, it lies loudly: raycasts always miss and
	timers never fire, which is stated rather than hidden.

	Two deliberate compromises are documented at their implementation below:
	SOURCE REWRITES and STUBBED REMOTES.
]]

local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Tree = require("./tree")

local Runtime = {}
Runtime.__index = Runtime

-- Signals -------------------------------------------------------------------

local function newSignal()
	local handlers = {}
	local signal = {}

	function signal:Connect(handler)
		table.insert(handlers, handler)
		return {
			Connected = true,
			Disconnect = function(connection)
				connection.Connected = false
				local index = table.find(handlers, handler)
				if index then
					table.remove(handlers, index)
				end
			end,
		}
	end

	function signal:Once(handler)
		return signal:Connect(handler)
	end

	function signal:Wait()
		return nil
	end

	function signal:Fire(...)
		for _, handler in table.clone(handlers) do
			handler(...)
		end
	end

	function signal:HandlerCount()
		return #handlers
	end

	return signal
end

Runtime.newSignal = newSignal

--[[
	SOURCE REWRITES

	Lune's Instance implementation has no WaitForChild (it cannot yield), and
	its metatable is locked so it cannot be extended. Rather than proxy every
	Instance — which breaks the moment something is assigned as a .Parent — the
	harness rewrites a short, explicit list of unsupported calls as the source
	is loaded.

	These are the only rewrites, and each is a call this runtime genuinely
	cannot provide. Anything else runs exactly as written.
]]
local REWRITES = {
	-- WaitForChild with a timeout, then without. Nothing yields here, so a
	-- child that is not already present is simply absent.
	{ ":WaitForChild%(([^,()]-),%s*[%d%.]+%)", ":FindFirstChild(%1)" },
	{ ":WaitForChild%(", ":FindFirstChild(" },
	-- Workspace helpers Lune does not implement.
	{ "Workspace:GetServerTimeNow%(%)", "__now()" },
	{ "workspace:GetServerTimeNow%(%)", "__now()" },
	{ "Workspace:Raycast%(", "__raycast(" },
	{ "workspace:Raycast%(", "__raycast(" },
	{ "Workspace:GetPropertyChangedSignal%(", "__propertySignal(" },
}

local function rewriteSource(source: string): string
	local result = source
	for _, rule in REWRITES do
		result = string.gsub(result, rule[1], rule[2])
	end
	return result
end

Runtime.rewriteSource = rewriteSource

-- Construction --------------------------------------------------------------

function Runtime.new(projectRoot: string)
	local self = setmetatable({
		root = projectRoot,
		moduleCache = {},
		taggedByTag = {},
		warnings = {},
		prints = {},
		deferred = {},
		remotes = {},
		remoteCalls = {},
		heartbeat = newSignal(),
		serverTime = 0,
	}, Runtime)

	self:_buildDataModel()
	self:_buildServices()
	self:_buildEnvironment()
	self:_stubRemotes()

	return self
end

function Runtime:_buildDataModel()
	self.workspace = roblox.Instance.new("Workspace")
	self.workspace.Name = "Workspace"
	-- Mirrors default.project.json.
	self.workspace.Gravity = 110
	self.workspace.FallenPartsDestroyHeight = -250

	self.replicatedStorage = roblox.Instance.new("ReplicatedStorage")

	-- Rojo's mapping: ReplicatedStorage.Shared and ServerScriptService.
	self.shared = Tree.fromDirectory(`{self.root}/src/ReplicatedStorage/Shared`, "Shared", rewriteSource)
	self.shared.Parent = self.replicatedStorage

	self.serverScriptService =
		Tree.fromDirectory(`{self.root}/src/ServerScriptService`, "ServerScriptService", rewriteSource)
end

function Runtime:_buildServices()
	local runtime = self

	local collectionService = {}
	function collectionService:AddTag(instance, tag)
		instance:AddTag(tag)
		local list = runtime.taggedByTag[tag]
		if not list then
			list = {}
			runtime.taggedByTag[tag] = list
		end
		table.insert(list, instance)
	end
	function collectionService:RemoveTag(instance, tag)
		instance:RemoveTag(tag)
		local list = runtime.taggedByTag[tag]
		if list then
			local index = table.find(list, instance)
			if index then
				table.remove(list, index)
			end
		end
	end
	function collectionService:HasTag(instance, tag)
		return instance:HasTag(tag)
	end
	function collectionService:GetTagged(tag)
		local result = {}
		for _, instance in runtime.taggedByTag[tag] or {} do
			-- A destroyed instance stops being tagged.
			local ok, parent = pcall(function()
				return instance.Parent
			end)
			if ok and parent ~= nil then
				table.insert(result, instance)
			end
		end
		return result
	end
	function collectionService:GetInstanceAddedSignal()
		return newSignal()
	end
	function collectionService:GetInstanceRemovedSignal()
		return newSignal()
	end

	local players = {
		PlayerAdded = newSignal(),
		PlayerRemoving = newSignal(),
		CharacterAutoLoads = true,
	}
	function players:GetPlayers()
		return {}
	end

	local runService = {
		Heartbeat = self.heartbeat,
		Stepped = newSignal(),
		RenderStepped = newSignal(),
	}
	function runService:IsServer()
		return true
	end
	function runService:IsClient()
		return false
	end
	function runService:IsStudio()
		return true
	end
	function runService:IsRunning()
		return true
	end
	function runService:BindToRenderStep() end
	function runService:UnbindFromRenderStep() end

	local physicsService = {}
	function physicsService:RegisterCollisionGroup() end
	function physicsService:CollisionGroupSetCollidable() end
	function physicsService:UnregisterCollisionGroup() end

	self.services = {
		Workspace = self.workspace,
		ReplicatedStorage = self.replicatedStorage,
		ServerScriptService = self.serverScriptService,
		CollectionService = collectionService,
		Players = players,
		RunService = runService,
		PhysicsService = physicsService,
		ServerStorage = roblox.Instance.new("Folder"),
		Lighting = roblox.Instance.new("Lighting"),
		SoundService = roblox.Instance.new("SoundService"),
	}
end

--[[
	STUBBED REMOTES

	Events.luau is replaced with a harness implementation. Lune has RemoteEvent
	instances but no OnServerEvent/FireClient, and this runtime has no clients
	to replicate to anyway.

	Every remote call is recorded, so a test can still assert that a service
	fired what it should — it just cannot assert that anyone received it.
]]
function Runtime:_stubRemotes()
	local runtime = self

	local function makeRemote(name: string)
		local remote = {
			Name = name,
			OnServerEvent = newSignal(),
			OnClientEvent = newSignal(),
			OnServerInvoke = nil,
		}

		local function record(kind: string, ...)
			table.insert(
				runtime.remoteCalls,
				{ remote = name, kind = kind, argumentCount = select("#", ...) }
			)
		end

		function remote:FireClient(...)
			record("FireClient", ...)
		end
		function remote:FireAllClients(...)
			record("FireAllClients", ...)
		end
		function remote:FireServer(...)
			record("FireServer", ...)
		end

		return remote
	end

	local Events = {}
	function Events.buildAll() end
	function Events.get(name: string)
		local remote = runtime.remotes[name]
		if not remote then
			remote = makeRemote(name)
			runtime.remotes[name] = remote
		end
		return remote
	end

	-- Seed the cache so the real module is never loaded.
	self.moduleCache[self.shared.Network.Events] = { value = Events }
end

function Runtime:_buildEnvironment()
	local runtime = self

	self.game = {
		Loaded = newSignal(),
	}
	function self.game:GetService(name: string)
		local service = runtime.services[name]
		if not service then
			error(`[runtime] service "{name}" is not shimmed — add it to runtime.luau`, 2)
		end
		return service
	end
	function self.game:IsLoaded()
		return true
	end
	function self.game:BindToClose() end
end

function Runtime:require(instance)
	local cached = self.moduleCache[instance]
	if cached ~= nil then
		return cached.value
	end

	local source = instance.Source
	if not source or source == "" then
		error(`[runtime] {instance:GetFullName()} has no source`, 2)
	end

	-- Guard against a require cycle presenting as a stack overflow.
	self.moduleCache[instance] = { value = nil, loading = true }
	local value = self:execute(source, instance, instance:GetFullName())
	self.moduleCache[instance] = { value = value }
	return value
end

function Runtime:execute(source: string, scriptInstance, debugName: string)
	local runtime = self

	local environment = {
		script = scriptInstance,
		game = self.game,
		workspace = self.workspace,
		Workspace = self.workspace,

		require = function(target)
			return runtime:require(target)
		end,

		-- Rewritten call targets. See SOURCE REWRITES.
		__now = function()
			return runtime.serverTime
		end,
		__raycast = function()
			-- No physics. Every cast misses, which is the honest answer:
			-- this runtime cannot tell you what a ray would hit.
			runtime.raycastCount = (runtime.raycastCount or 0) + 1
			return nil
		end,
		__propertySignal = function()
			return newSignal()
		end,

		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		BrickColor = roblox.BrickColor,
		NumberRange = roblox.NumberRange,
		Random = Random,

		RaycastParams = {
			new = function()
				return {
					FilterType = nil,
					FilterDescendantsInstances = {},
					IgnoreWater = false,
					CollisionGroup = "Default",
				}
			end,
		},

		warn = function(...)
			local parts = {}
			for index = 1, select("#", ...) do
				parts[index] = tostring((select(index, ...)))
			end
			table.insert(runtime.warnings, table.concat(parts, " "))
		end,

		print = function(...)
			local parts = {}
			for index = 1, select("#", ...) do
				parts[index] = tostring((select(index, ...)))
			end
			table.insert(runtime.prints, table.concat(parts, " "))
		end,

		task = {
			spawn = function(fn, ...)
				local ok, err = pcall(fn, ...)
				if not ok then
					table.insert(runtime.warnings, `task.spawn error: {err}`)
				end
			end,
			defer = function(fn, ...)
				local args = table.pack(...)
				table.insert(runtime.deferred, function()
					fn(table.unpack(args, 1, args.n))
				end)
			end,
			delay = function()
				-- Timers never fire here. Anything gated on one is out of
				-- scope for a boot smoke test.
				return nil
			end,
			wait = function()
				return 0
			end,
			cancel = function() end,
		},
	}

	local chunk = luau.load(source, {
		debugName = debugName,
		environment = environment,
		injectGlobals = true,
	})

	return chunk()
end

function Runtime:flushDeferred()
	local queue = self.deferred
	self.deferred = {}
	for _, fn in queue do
		local ok, err = pcall(fn)
		if not ok then
			table.insert(self.warnings, `deferred error: {err}`)
		end
	end
end

function Runtime:stepHeartbeat(deltaTime: number)
	self.serverTime += deltaTime
	self.heartbeat:Fire(deltaTime)
end

--[[
	Boots the server the way ServerBootstrap does: remotes, then Init in order,
	then Start in order.

	The order is passed in — smoke.luau reads it out of ServerBootstrap itself
	so the harness cannot silently drift from the real boot sequence.
]]
function Runtime:bootServer(serviceOrder: { string })
	local servicesFolder = self.serverScriptService:FindFirstChild("Services")
	if not servicesFolder then
		return false, "ServerScriptService.Services is missing"
	end

	local services = {}
	local ordered = {}

	for _, name in serviceOrder do
		local module = servicesFolder:FindFirstChild(name)
		if not module then
			return false, `service module {name} is missing from Services/`
		end

		local ok, result = pcall(function()
			return self:require(module)
		end)
		if not ok then
			return false, `requiring {name}: {result}`
		end

		result.Name = name
		services[name] = result
		table.insert(ordered, result)
	end

	local context = { services = services, isStudio = true }
	self.context = context

	for _, service in ordered do
		if service.Init then
			local ok, err = pcall(service.Init, service, context)
			if not ok then
				return false, `{service.Name}:Init — {err}`
			end
		end
	end

	for _, service in ordered do
		if service.Start then
			local ok, err = pcall(service.Start, service, context)
			if not ok then
				return false, `{service.Name}:Start — {err}`
			end
		end
	end

	return true, nil
end

return Runtime
