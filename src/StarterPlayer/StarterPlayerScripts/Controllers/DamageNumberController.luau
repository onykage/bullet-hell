--!strict
--[[
	DamageNumberController.luau

	Floating damage numbers.

	They exist to answer one question instantly: "did that shot do what I
	expected?" That makes them a build-feedback tool, not decoration — which
	drives every decision here:

	  * Numbers are spawned from the server's confirmed damage, never from the
	    client's prediction. A number that disagrees with reality is worse than
	    no number.
	  * Rapid hits on the same target MERGE into a running total rather than
	    stacking 14 overlapping labels for one SMG burst. You read "168", not a
	    smear.
	  * Crits are visually distinct by size, colour AND weight, so the
	    distinction survives colourblindness and a low graphics setting (§17.4).
	  * Magnitude scales the font, so a weak-point hit is legible as big without
	    needing to read the digits.
	  * Everything is pooled and hard-capped (§16.3, §16.4) — a bullet-hell
	    fight must not be able to drown the frame budget in text.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Events = require(Shared.Network.Events)
local Pool = require(Shared.Utility.Pool)

local LIFETIME = 0.95
local MERGE_WINDOW = 0.22 -- hits on one target within this window combine
local MERGE_DISTANCE = 7

local COLORS = {
	normal = Color3.fromRGB(255, 246, 224),
	critical = Color3.fromRGB(255, 196, 72),
	weakPoint = Color3.fromRGB(120, 235, 255),
	kill = Color3.fromRGB(255, 118, 118),
}

local DamageNumberController = {}

type Floater = {
	billboard: BillboardGui,
	label: TextLabel,
	anchor: Part,
	total: number,
	spawnedAt: number,
	lastHitAt: number,
	targetId: string,
	isCritical: boolean,
	killed: boolean,
	drift: Vector3,
	origin: Vector3,
}

function DamageNumberController:Init()
	self.container = Instance.new("Folder")
	self.container.Name = "DamageNumbers"
	self.container.Parent = Workspace

	self.active = {} :: { Floater }

	self.pool = Pool.new(function(): Floater
		local anchor = Instance.new("Part")
		anchor.Name = "DamageAnchor"
		anchor.Size = Vector3.new(0.05, 0.05, 0.05)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Parent = self.container

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "DamageNumber"
		billboard.Size = UDim2.fromScale(4, 2)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 260
		billboard.LightInfluence = 0
		billboard.Adornee = anchor
		billboard.Enabled = false
		billboard.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Name = "Value"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.25
		label.TextStrokeColor3 = Color3.fromRGB(12, 10, 14)
		label.Parent = billboard

		return {
			billboard = billboard,
			label = label,
			anchor = anchor,
			total = 0,
			spawnedAt = 0,
			lastHitAt = 0,
			targetId = "",
			isCritical = false,
			killed = false,
			drift = Vector3.zero,
			origin = Vector3.zero,
		}
	end, function(floater: Floater)
		floater.billboard.Enabled = false
		floater.total = 0
		floater.targetId = ""
	end, 24, Balance.Limits.MaxDamageNumbersOnScreen)
end

function DamageNumberController:Start()
	self.damageRemote = Events.get("S2C_DamageDealt")

	self.damageRemote.OnClientEvent:Connect(function(payload)
		self:Add(payload)
	end)

	RunService.RenderStepped:Connect(function()
		self:_update()
	end)
end

function DamageNumberController:Add(payload: {
	position: Vector3,
	amount: number,
	isCritical: boolean,
	hitRegion: string?,
	killed: boolean,
	targetId: string,
})
	if payload.amount <= 0 then
		return
	end

	local now = os.clock()

	-- Merge into a recent number on the same target rather than stacking.
	for _, floater in self.active do
		if floater.targetId ~= payload.targetId then
			continue
		end
		if now - floater.lastHitAt > MERGE_WINDOW then
			continue
		end
		if (floater.origin - payload.position).Magnitude > MERGE_DISTANCE then
			continue
		end

		floater.total += payload.amount
		floater.lastHitAt = now
		-- Refresh the life so a sustained burst keeps one readable number
		-- alive instead of flickering.
		floater.spawnedAt = now - LIFETIME * 0.25
		floater.isCritical = floater.isCritical or payload.isCritical
		floater.killed = floater.killed or payload.killed
		self:_style(floater, payload.hitRegion)
		return
	end

	-- Over budget: drop the oldest rather than exceeding the cap.
	if #self.active >= Balance.Limits.MaxDamageNumbersOnScreen then
		local oldest = table.remove(self.active, 1)
		if oldest then
			self.pool:Release(oldest)
		end
	end

	local floater = self.pool:Get()
	floater.total = payload.amount
	floater.spawnedAt = now
	floater.lastHitAt = now
	floater.targetId = payload.targetId
	floater.isCritical = payload.isCritical
	floater.killed = payload.killed
	floater.origin = payload.position

	-- A small random sideways drift keeps simultaneous pellet hits from
	-- overlapping into an unreadable pile.
	floater.drift = Vector3.new((math.random() - 0.5) * 3.2, 0, (math.random() - 0.5) * 3.2)

	floater.anchor.Position = payload.position
	floater.billboard.Enabled = true
	self:_style(floater, payload.hitRegion)

	table.insert(self.active, floater)
end

function DamageNumberController:_style(floater: Floater, hitRegion: string?)
	local label = floater.label
	local total = floater.total

	local color = COLORS.normal
	local prefix = ""

	if floater.killed then
		color = COLORS.kill
	elseif hitRegion == "WeakPoint" then
		color = COLORS.weakPoint
		prefix = "◆ "
	elseif floater.isCritical then
		color = COLORS.critical
		prefix = "✦ "
	end

	label.TextColor3 = color
	label.Text = prefix .. tostring(math.floor(total + 0.5))
	-- Crits and big numbers read as bigger, so magnitude is legible before the
	-- digits are.
	local magnitudeScale = 1 + math.clamp(total / 220, 0, 0.7)
	local critScale = if floater.isCritical then 1.25 else 1
	floater.billboard.Size = UDim2.fromScale(4 * magnitudeScale * critScale, 2 * magnitudeScale * critScale)
end

function DamageNumberController:_update()
	local now = os.clock()

	for index = #self.active, 1, -1 do
		local floater = self.active[index]
		local age = now - floater.spawnedAt

		if age >= LIFETIME then
			self.pool:Release(floater)
			table.remove(self.active, index)
			continue
		end

		local alpha = age / LIFETIME

		-- Rise quickly then slow: the number is most readable while it is near
		-- where the hit landed.
		local rise = 1 - (1 - alpha) * (1 - alpha)
		floater.anchor.Position = floater.origin + Vector3.new(0, rise * 5.5, 0) + floater.drift * rise

		-- Hold full opacity for most of the life, then fade out fast.
		floater.label.TextTransparency = math.clamp((alpha - 0.65) / 0.35, 0, 1)
		floater.label.TextStrokeTransparency = 0.25 + math.clamp((alpha - 0.65) / 0.35, 0, 0.75)
	end
end

return DamageNumberController
