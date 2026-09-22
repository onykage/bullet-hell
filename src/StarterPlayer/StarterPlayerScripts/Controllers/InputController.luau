--!strict
--[[
	InputController.luau

	One place that maps physical input to intent (§C5, §C17).

	Every other controller reads intent — "is fire held", "did dash fire this
	frame" — and never touches UserInputService. That is what makes gamepad and
	touch support an addition here rather than a change everywhere.

	ContextActionService is used rather than raw input so bindings can be
	suspended cleanly while a menu has focus.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local InputController = {}

export type State = {
	firing: boolean,
	aiming: boolean,
	sprinting: boolean,
	crouching: boolean,
}

function InputController:Init()
	self.state = {
		firing = false,
		aiming = false,
		sprinting = false,
		crouching = false,
	} :: State

	-- Edge-triggered intents, consumed once by whoever handles them.
	self._pending = {
		Dash = false,
		Slide = false,
		Jump = false,
		Reload = false,
		SwapNext = false,
		SwapPrevious = false,
	}

	self._slotRequest = nil :: number?
end

function InputController:Start()
	local function bind(name: string, handler: (string, Enum.UserInputState, InputObject) -> any, ...)
		ContextActionService:BindAction(name, handler, false, ...)
	end

	bind("Fire", function(_, inputState)
		self.state.firing = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	bind("Aim", function(_, inputState)
		self.state.aiming = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

	bind("Sprint", function(_, inputState)
		self.state.sprinting = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	bind("Crouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self.state.crouching = true
			-- Crouch while sprinting is the slide input; the movement
			-- controller decides whether the entry conditions are met.
			if self.state.sprinting then
				self._pending.Slide = true
			end
		elseif inputState == Enum.UserInputState.End then
			self.state.crouching = false
		end
		return Enum.ContextActionResult.Pass
	end, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)

	bind("Reload", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self._pending.Reload = true
		end
		return Enum.ContextActionResult.Pass
	end, Enum.KeyCode.R, Enum.KeyCode.ButtonX)

	bind("Dash", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self._pending.Dash = true
		end
		return Enum.ContextActionResult.Pass
	end, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)

	-- Jump is observed rather than bound, so the default Roblox jump still
	-- works; the movement controller only needs to know a press happened in
	-- order to decide whether it is an air jump.
	UserInputService.JumpRequest:Connect(function()
		self._pending.Jump = true
	end)

	local SLOT_KEYS =
		{ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
	for slot, keyCode in SLOT_KEYS do
		ContextActionService:BindAction(`Slot{slot}`, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				self._slotRequest = slot
			end
			return Enum.ContextActionResult.Pass
		end, false, keyCode)
	end

	ContextActionService:BindAction("SwapNext", function(_, inputState, input)
		if inputState == Enum.UserInputState.Change and input.Position.Z ~= 0 then
			if input.Position.Z > 0 then
				self._pending.SwapPrevious = true
			else
				self._pending.SwapNext = true
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseWheel)
end

--[[
	The player's intended move direction, taken from the Humanoid so it already
	accounts for camera-relative movement, gamepad thumbstick, and touch.
]]
function InputController:GetMoveDirection(): Vector3
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid then humanoid.MoveDirection else Vector3.zero
end

--[[
	Reads and clears an edge-triggered intent. Consuming it here means two
	controllers cannot both act on the same key press.
]]
function InputController:Consume(action: string): boolean
	if self._pending[action] then
		self._pending[action] = false
		return true
	end
	return false
end

function InputController:ConsumeSlot(): number?
	local slot = self._slotRequest
	self._slotRequest = nil
	return slot
end

function InputController:GetState(): State
	return self.state
end

return InputController
