--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local InputController = require(script.Parent:WaitForChild("InputController"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WeaponSelectionConfig"))

local ACTION = "NeonBreakerSelectStageWeapon"
local WeaponSelectionController = {}
local connections: { RBXScriptConnection } = {}
local started = false
local stageState: string? = nil

local function SetStageState(nextState: string)
	if nextState == stageState then return end
	stageState = nextState
	if nextState == "Waiting" then
		print("[WeaponSelection] 武器を選択: 1=AssaultRifle / 2=Shotgun / 3=Handgun。全員の選択後に開始します。")
	else
		print("[WeaponSelection] 武器選択終了: " .. nextState)
	end
end

function WeaponSelectionController.Init()
	if started then return end
	assert(RunService:IsClient(), "WeaponSelectionController must run on the client")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local selectWeapon = remotes:WaitForChild("Lobby"):WaitForChild("SelectWeapon")
	local stageChanged = remotes:WaitForChild("Stage"):WaitForChild("StageStateChanged")
	assert(selectWeapon:IsA("RemoteEvent") and stageChanged:IsA("RemoteEvent"), "Selection remotes must be RemoteEvents")
	if started then return end
	started = true
	local received = false
	local pending = false
	local elapsed = 0
	local nextSelectAt = 0
	table.insert(connections, stageChanged.OnClientEvent:Connect(function(snapshot)
		SetStageState(snapshot.State)
	end))
	table.insert(connections, selectWeapon.OnClientEvent:Connect(function(snapshot)
		received = true
		pending = false
		elapsed = 0
		SetStageState(snapshot.StageState)
		if snapshot.Success then
			print("[WeaponSelection] 選択確定: " .. snapshot.CurrentWeaponId)
		elseif snapshot.Reason ~= "Snapshot" then
			warn("[WeaponSelection] 選択拒否: " .. snapshot.Reason)
		end
	end))
	local keys: { Enum.KeyCode } = {}
	for key in Config.KeyBindings do table.insert(keys, key) end
	-- Take priority over the default backpack's number keys only while selecting.
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState: Enum.UserInputState, input: InputObject)
		if stageState ~= "Waiting" or GuiService.MenuIsOpen or InputController.IsUIBlocked()
			or UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			local weaponId = Config.KeyBindings[input.KeyCode]
			local now = os.clock()
			if weaponId and now >= nextSelectAt then
				nextSelectAt = now + Config.RequestInterval
				pending = true
				elapsed = 0
				selectWeapon:FireServer(weaponId)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(keys))
	table.insert(connections, RunService.Heartbeat:Connect(function(dt: number)
		if received and not pending then return end
		elapsed += dt
		if elapsed >= Config.SnapshotRetryInterval then
			elapsed = 0
			selectWeapon:FireServer()
		end
	end))
	selectWeapon:FireServer()
	stageChanged:FireServer()
end

function WeaponSelectionController.Destroy()
	if not started then return end
	started = false
	ContextActionService:UnbindAction(ACTION)
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	stageState = nil
end

return WeaponSelectionController
