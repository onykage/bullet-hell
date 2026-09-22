--!strict
--[[
	Loading.client.luau

	Replaces the default loading screen so the player never sees a
	half-generated graybox world assemble around them.

	ReplicatedFirst runs before anything else replicates, which is the only
	place this can be done without a visible flash.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = player:WaitForChild("PlayerGui")

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(14, 13, 18)
background.BorderSizePixel = 0
background.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.2)
title.Position = UDim2.fromScale(0, 0.4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 34
title.TextColor3 = Color3.fromRGB(255, 176, 64)
title.Text = "THE STORM ENGINE"
title.Parent = background

local status = Instance.new("TextLabel")
status.Size = UDim2.fromScale(1, 0.1)
status.Position = UDim2.fromScale(0, 0.56)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 15
status.TextColor3 = Color3.fromRGB(150, 156, 170)
status.Text = "Building the frontier..."
status.Parent = background

task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	status.Text = "Ready"
	task.wait(0.4)

	for alpha = 0, 1, 0.04 do
		background.BackgroundTransparency = alpha
		title.TextTransparency = alpha
		status.TextTransparency = alpha
		RunService.RenderStepped:Wait()
	end

	gui:Destroy()
end)
