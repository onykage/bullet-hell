--!strict
--[[
	HUDController.luau

	Combat HUD (§17.1): crosshair with live spread, ammo, health, ability
	cooldowns, hitmarker, boss health and phase, and a damage-direction
	indicator.

	Built in code rather than authored in Studio for the slice, because the HUD
	needs to respond to values (spread in degrees, cooldown fractions) that only
	exist at runtime. The Studio workstream owns final art and layout review
	(§R13); this controller exposes a small setter API, so re-skinning it later
	does not touch any gameplay code.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Network.Events)

local ACCENT = Color3.fromRGB(255, 176, 64)
local DIM = Color3.fromRGB(196, 202, 214)

local HUDController = {}

local function newFrame(name: string, parent: Instance, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function newLabel(name: string, parent: Instance, text: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = size
	label.TextColor3 = DIM
	label.TextStrokeTransparency = 0.6
	label.Text = text
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = parent
	return label
end

function HUDController:Init(context)
	self.player = context.player
	self.spreadDegrees = 1.2
	self.hitmarkerUntil = 0
	self.dodgeFlashUntil = 0
	self.damageIndicators = {} :: { { direction: Vector3, expiresAt: number, frame: Frame } }

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = self.player:WaitForChild("PlayerGui")
	self.gui = gui

	self:_buildCrosshair(gui)
	self:_buildAmmo(gui)
	self:_buildVitals(gui)
	self:_buildAbilities(gui)
	self:_buildBossBar(gui)
end

function HUDController:Start()
	self.healthRemote = Events.get("S2C_DamageTaken")
	self.bossRemote = Events.get("S2C_BossState")
	self.damageRemote = Events.get("S2C_DamageDealt")
	self.arenaRemote = Events.get("S2C_ArenaState")

	self.damageRemote.OnClientEvent:Connect(function()
		-- Hitmarker fires on the server's confirmation, so it never lies about
		-- a hit the server rejected.
		self.hitmarkerUntil = os.clock() + 0.12
	end)

	self.healthRemote.OnClientEvent:Connect(function(payload)
		self:SetHealth(payload.health, payload.maxHealth)
		self:_addDamageIndicator(payload.sourcePosition)
	end)

	self.bossRemote.OnClientEvent:Connect(function(state)
		self:SetBossState(state)
	end)

	self.arenaRemote.OnClientEvent:Connect(function(state)
		if state.state == "Returned" then
			self:SetBossState(nil)
		end
	end)

	local function bind(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local function sync()
			self:SetHealth(humanoid.Health, humanoid.MaxHealth)
		end
		humanoid.HealthChanged:Connect(sync)
		sync()
	end

	self.player.CharacterAdded:Connect(bind)
	if self.player.Character then
		bind(self.player.Character)
	end

	RunService.RenderStepped:Connect(function()
		self:_update()
	end)
end

function HUDController:_buildCrosshair(gui: ScreenGui)
	local container = newFrame("Crosshair", gui, UDim2.fromOffset(180, 180), UDim2.fromScale(0.5, 0.5))
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	self.crosshair = container

	self.crosshairLines = {}
	-- Four lines that separate as spread grows: the crosshair IS the spread
	-- readout, so the player never has to guess their accuracy (§17.1).
	for _, definition in { { "Top", 0, -1 }, { "Bottom", 0, 1 }, { "Left", -1, 0 }, { "Right", 1, 0 } } do
		local name, dx, dy = definition[1], definition[2], definition[3]
		local line = Instance.new("Frame")
		line.Name = name :: string
		line.BackgroundColor3 = Color3.fromRGB(240, 244, 252)
		line.BackgroundTransparency = 0.15
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Size = if dx == 0 then UDim2.fromOffset(2, 9) else UDim2.fromOffset(9, 2)
		line.Parent = container
		table.insert(self.crosshairLines, { frame = line, dx = dx :: number, dy = dy :: number })
	end

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.fromOffset(2, 2)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BorderSizePixel = 0
	dot.Parent = container

	local hitmarker = newLabel("Hitmarker", container, "✕", 22)
	hitmarker.TextColor3 = Color3.fromRGB(255, 228, 160)
	hitmarker.TextTransparency = 1
	self.hitmarker = hitmarker
end

function HUDController:_buildAmmo(gui: ScreenGui)
	local container = newFrame("Ammo", gui, UDim2.fromOffset(300, 80), UDim2.new(1, -330, 1, -120))
	self.ammoLabel = newLabel("Value", container, "--", 40)
	self.ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.ammoLabel.TextColor3 = Color3.fromRGB(240, 244, 252)

	local nameContainer = newFrame("WeaponName", container, UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.72))
	self.weaponLabel = newLabel("Value", nameContainer, "", 16)
	self.weaponLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.weaponLabel.TextColor3 = ACCENT
end

function HUDController:_buildVitals(gui: ScreenGui)
	local container = newFrame("Vitals", gui, UDim2.fromOffset(340, 60), UDim2.new(0, 40, 1, -120))

	local bar = Instance.new("Frame")
	bar.Name = "HealthBack"
	bar.Size = UDim2.fromOffset(300, 14)
	bar.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	bar.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = "HealthFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(104, 224, 152)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	self.healthFill = fill

	local labelHolder = newFrame("HealthLabel", container, UDim2.fromOffset(300, 22), UDim2.fromOffset(0, 18))
	self.healthLabel = newLabel("Value", labelHolder, "100 / 100", 15)
	self.healthLabel.TextXAlignment = Enum.TextXAlignment.Left
end

function HUDController:_buildAbilities(gui: ScreenGui)
	local container = newFrame("Abilities", gui, UDim2.fromOffset(340, 40), UDim2.new(0, 40, 1, -70))
	self.abilityPips = {}

	local order = { "Dash", "Slide", "DoubleJump" }
	local labels = { Dash = "DASH  Q", Slide = "SLIDE  SHIFT+C", DoubleJump = "AIR JUMP  SPACE" }

	for index, ability in order do
		local pip = Instance.new("Frame")
		pip.Name = ability
		pip.Size = UDim2.fromOffset(104, 6)
		pip.Position = UDim2.fromOffset((index - 1) * 112, 0)
		pip.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
		pip.BorderSizePixel = 0
		pip.Parent = container

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = pip

		local holder =
			newFrame("Label", container, UDim2.fromOffset(104, 16), UDim2.fromOffset((index - 1) * 112, 9))
		local label = newLabel("Value", holder, labels[ability], 11)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(150, 156, 170)

		self.abilityPips[ability] = fill
	end
end

function HUDController:_buildBossBar(gui: ScreenGui)
	local container = newFrame("BossBar", gui, UDim2.fromOffset(720, 70), UDim2.new(0.5, -360, 0, 40))
	container.Visible = false
	self.bossBar = container

	local nameHolder = newFrame("Name", container, UDim2.fromOffset(720, 22), UDim2.fromOffset(0, 0))
	self.bossNameLabel = newLabel("Value", nameHolder, "", 18)
	self.bossNameLabel.TextColor3 = Color3.fromRGB(240, 244, 252)

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromOffset(720, 16)
	back.Position = UDim2.fromOffset(0, 26)
	back.BackgroundColor3 = Color3.fromRGB(22, 20, 28)
	back.BorderSizePixel = 0
	back.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(196, 96, 220)
	fill.BorderSizePixel = 0
	fill.Parent = back
	self.bossFill = fill

	local phaseHolder = newFrame("Phase", container, UDim2.fromOffset(720, 20), UDim2.fromOffset(0, 46))
	self.bossPhaseLabel = newLabel("Value", phaseHolder, "", 14)
	self.bossPhaseLabel.TextColor3 = ACCENT
end

function HUDController:SetWeapon(info: {
	displayName: string,
	ammo: number,
	magazine: number,
	reserve: number,
	reloading: boolean,
	spread: number,
})
	self.spreadDegrees = info.spread
	self.weaponLabel.Text = string.upper(info.displayName)

	if info.reloading then
		self.ammoLabel.Text = "RELOADING"
		self.ammoLabel.TextColor3 = ACCENT
	else
		self.ammoLabel.Text = `{info.ammo} / {info.reserve}`
		-- Low magazine turns the readout warm: a reload prompt you feel rather
		-- than read.
		self.ammoLabel.TextColor3 = if info.ammo <= math.max(1, info.magazine * 0.25)
			then Color3.fromRGB(255, 132, 108)
			else Color3.fromRGB(240, 244, 252)
	end
end

function HUDController:SetHealth(health: number, maxHealth: number)
	local fraction = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	self.healthFill.Size = UDim2.fromScale(fraction, 1)
	self.healthFill.BackgroundColor3 = if fraction < 0.3
		then Color3.fromRGB(240, 96, 96)
		elseif fraction < 0.6 then Color3.fromRGB(240, 196, 96)
		else Color3.fromRGB(104, 224, 152)
	self.healthLabel.Text = `{math.floor(health + 0.5)} / {math.floor(maxHealth + 0.5)}`
end

function HUDController:SetAbilityCooldowns(fractions: { [string]: number })
	for ability, fill in self.abilityPips do
		local value = fractions[ability]
		if value == nil then
			continue
		end
		fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
		fill.BackgroundColor3 = if value >= 1 then ACCENT else Color3.fromRGB(96, 100, 116)
	end
end

function HUDController:FlashDodge(duration: number)
	self.dodgeFlashUntil = os.clock() + duration
end

function HUDController:SetBossState(state: any?)
	if not state or state.phase == "Dormant" or state.phase == "Reset" then
		self.bossBar.Visible = false
		return
	end

	self.bossBar.Visible = true
	self.bossNameLabel.Text = string.upper(state.displayName or "BOSS")

	local fraction = if state.maxHealth > 0 then math.clamp(state.health / state.maxHealth, 0, 1) else 0
	self.bossFill.Size = UDim2.fromScale(fraction, 1)

	-- The phase line tells the player what to DO, not just what phase it is:
	-- a health bar that will not move is the single most confusing thing a
	-- boss can present (§2.6 fairness is visible).
	local phaseText = state.phase
	if state.conductorsAlive and state.conductorsAlive > 0 then
		phaseText ..= `  —  DESTROY CONDUCTORS  ({state.conductorsAlive}/{state.conductorsTotal} standing, {math.floor(
			(state.damageReduction or 0) * 100
		)}% damage resisted)`
	elseif state.phase == "PhaseOne" or state.phase == "PhaseTwo" then
		phaseText ..= "  —  DAMAGE WINDOW OPEN"
	end
	self.bossPhaseLabel.Text = phaseText
end

function HUDController:_addDamageIndicator(sourcePosition: Vector3?)
	if not sourcePosition then
		return
	end

	local frame = Instance.new("Frame")
	frame.Name = "DamageIndicator"
	frame.Size = UDim2.fromOffset(70, 5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(255, 92, 92)
	frame.BorderSizePixel = 0
	frame.Parent = self.gui

	table.insert(self.damageIndicators, {
		direction = sourcePosition,
		expiresAt = os.clock() + 1.4,
		frame = frame,
	})
end

function HUDController:_update()
	local now = os.clock()

	-- Crosshair gap tracks the real spread value from the shared weapon math.
	local gap = 6 + self.spreadDegrees * 7
	for _, line in self.crosshairLines do
		line.frame.Position = UDim2.new(0.5, line.dx * gap, 0.5, line.dy * gap)
	end

	self.hitmarker.TextTransparency = if now < self.hitmarkerUntil then 0 else 1

	-- Dodge i-frames get a visible tell, so players learn the window's length.
	local dodging = now < self.dodgeFlashUntil
	for _, line in self.crosshairLines do
		line.frame.BackgroundColor3 = if dodging
			then Color3.fromRGB(120, 235, 255)
			else Color3.fromRGB(240, 244, 252)
	end

	local camera = Workspace.CurrentCamera
	for index = #self.damageIndicators, 1, -1 do
		local indicator = self.damageIndicators[index]
		if now >= indicator.expiresAt or not camera then
			indicator.frame:Destroy()
			table.remove(self.damageIndicators, index)
			continue
		end

		local character = self.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local toSource = (indicator.direction - root.Position) * Vector3.new(1, 0, 1)
		local forward = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if toSource.Magnitude < 0.01 or forward.Magnitude < 0.01 then
			continue
		end

		local angle = math.atan2(toSource.Unit:Cross(forward.Unit).Y, toSource.Unit:Dot(forward.Unit))
		local radius = 150
		indicator.frame.Position = UDim2.new(0.5, -math.sin(angle) * radius, 0.5, -math.cos(angle) * radius)
		indicator.frame.Rotation = -math.deg(angle)
		indicator.frame.BackgroundTransparency = 1 - math.clamp((indicator.expiresAt - now) / 1.4, 0, 1)
	end
end

return HUDController
