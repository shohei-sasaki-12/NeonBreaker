--!strict

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Local notifications only. Consumers decide what actions are allowed.
local events = {
	FirePressed = Instance.new("BindableEvent"),
	FireReleased = Instance.new("BindableEvent"),
	Aim = Instance.new("BindableEvent"),
	Reload = Instance.new("BindableEvent"),
	Dash = Instance.new("BindableEvent"),
	SpecialEquipment = Instance.new("BindableEvent"),
	Interact = Instance.new("BindableEvent"),
}

local InputController = {
	FirePressed = events.FirePressed.Event,
	FireReleased = events.FireReleased.Event,
	Aim = events.Aim.Event, -- (isHeld: boolean)
	Reload = events.Reload.Event,
	Dash = events.Dash.Event,
	SpecialEquipment = events.SpecialEquipment.Event,
	Interact = events.Interact.Event, -- (isHeld: boolean); also used for revive requests.
}

local keyActions: { [Enum.KeyCode]: BindableEvent } = {
	[Enum.KeyCode.R] = events.Reload,
	[Enum.KeyCode.LeftShift] = events.Dash,
	[Enum.KeyCode.RightShift] = events.Dash,
	[Enum.KeyCode.Q] = events.SpecialEquipment,
}
local connections: { RBXScriptConnection } = {}
local heldKeys: { [Enum.KeyCode]: boolean } = {}
local started = false
local focused = true
local firing = false
local aiming = false
local interacting = false

local function ReleaseHeldInputs()
	if firing then
		firing = false
		events.FireReleased:Fire()
	end
	if aiming then
		aiming = false
		events.Aim:Fire(false)
	end
	if interacting then
		interacting = false
		events.Interact:Fire(false)
	end
	table.clear(heldKeys)
end

local function OnInputBegan(input: InputObject, processed: boolean)
	if processed or not focused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not firing then
			firing = true
			events.FirePressed:Fire()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if not aiming then
			aiming = true
			events.Aim:Fire(true)
		end
	elseif input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode
		if heldKeys[key] then
			return
		end
		heldKeys[key] = true
		if key == Enum.KeyCode.E then
			interacting = true
			events.Interact:Fire(true)
		else
			local action = keyActions[key]
			if action then
				action:Fire()
			end
		end
	end
end

local function OnInputEnded(input: InputObject)
	-- Always release accepted inputs, even when UI consumes their release.
	if input.UserInputType == Enum.UserInputType.MouseButton1 and firing then
		firing = false
		events.FireReleased:Fire()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and aiming then
		aiming = false
		events.Aim:Fire(false)
	elseif input.UserInputType == Enum.UserInputType.Keyboard then
		heldKeys[input.KeyCode] = nil
		if input.KeyCode == Enum.KeyCode.E and interacting then
			interacting = false
			events.Interact:Fire(false)
		end
	end
end

function InputController.Init()
	if started then
		return
	end
	assert(RunService:IsClient(), "InputController must run on the client")
	started = true
	focused = true
	table.insert(connections, UserInputService.InputBegan:Connect(OnInputBegan))
	table.insert(connections, UserInputService.InputEnded:Connect(OnInputEnded))
	table.insert(connections, UserInputService.TextBoxFocused:Connect(ReleaseHeldInputs))
	table.insert(connections, GuiService.MenuOpened:Connect(ReleaseHeldInputs))
	table.insert(connections, Players.LocalPlayer.CharacterRemoving:Connect(ReleaseHeldInputs))
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		ReleaseHeldInputs()
	end))
	table.insert(connections, UserInputService.WindowFocused:Connect(function()
		focused = true
	end))
end

function InputController.Destroy()
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	ReleaseHeldInputs()
	-- Keep notification objects stable so subscribers survive a later Init().
end

return InputController
