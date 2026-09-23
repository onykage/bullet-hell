--!strict
--[[
	DiagnosticsController.luau

	Turns "nothing loaded" into a sentence.

	Two failures used to look identical from the player's seat — a blank world
	with no explanation:

	  1. a service errored during boot, so nothing was ever built
	  2. the server booted but the world container is empty

	Both now put a readable banner on screen naming what happened. This is a
	development aid, so it only shows itself when something is actually wrong;
	a healthy boot draws nothing at all.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- How long the world gets to appear before we call it missing. Generous: the
-- server may be building a large graybox, and a false alarm is worse than a
-- slow one.
local WORLD_TIMEOUT = 8

local DiagnosticsController = {}

function DiagnosticsController:Init(context)
	self.player = context.player
	self.shown = false
	self.startedAt = os.clock()
end

function DiagnosticsController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Diagnostics"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 500
	gui.Enabled = false
	gui.Parent = self.player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 96)
	frame.BackgroundColor3 = Color3.fromRGB(122, 28, 32)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -48, 1, -24)
	label.Position = UDim2.fromOffset(24, 12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(255, 232, 232)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = ""
	label.Parent = frame

	self.gui = gui
	self.label = label

	-- A boot failure may be published before or after this controller starts,
	-- so check the current value and then listen.
	ReplicatedStorage:GetAttributeChangedSignal("BootStatus"):Connect(function()
		self:_checkBootStatus()
	end)
	self:_checkBootStatus()

	RunService.Heartbeat:Connect(function()
		self:_checkWorld()
	end)
end

function DiagnosticsController:_show(text: string)
	if self.shown then
		return
	end
	self.shown = true
	self.label.Text = text
	self.gui.Enabled = true
	warn(`[Diagnostics] {text}`)
end

function DiagnosticsController:_checkBootStatus()
	if ReplicatedStorage:GetAttribute("BootStatus") ~= "Failed" then
		return
	end

	local detail = ReplicatedStorage:GetAttribute("BootError") or "no detail published"
	self:_show(
		-- The message is the whole story on purpose. Pointing at a server log
		-- is useless when the failure is that the server never finished
		-- starting, so there is no log to go and read.
		`SERVER BOOT FAILED\n\n{detail}\n\n`
			.. "No further services started and no world was built. "
			.. "The line above is the complete error."
	)
end

function DiagnosticsController:_checkWorld()
	if self.shown or os.clock() - self.startedAt < WORLD_TIMEOUT then
		return
	end

	local world = Workspace:FindFirstChild("World")
	if world and #world:GetChildren() > 0 then
		-- Healthy. Stop paying for this check.
		self.shown = true
		return
	end

	local status = ReplicatedStorage:GetAttribute("BootStatus") or "unknown"
	self:_show(
		`WORLD IS EMPTY after {WORLD_TIMEOUT}s — boot status: {status}\n\n`
			.. "Workspace.World has no children. Either WorldBuilderService never ran, "
			.. "or it found authored geometry already present and stood down."
	)
end

return DiagnosticsController
