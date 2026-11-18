--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Snapshot = { State: string, DropPodState: string?, AlarmActive: boolean }
local StageAlertController = {}
local gui: ScreenGui? = nil
local connection: RBXScriptConnection? = nil

function StageAlertController.Init()
	if gui then return end
	local stage = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Stage")
	local stateChanged = stage:WaitForChild("StageStateChanged")
	assert(stateChanged:IsA("RemoteEvent"), "StageStateChanged must be a RemoteEvent")

	local screen = Instance.new("ScreenGui")
	screen.Name = "StageAlertUI"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 10
	screen.Enabled = false
	gui = screen

	local label = Instance.new("TextLabel")
	label.Name = "Alert"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 16)
	label.Size = UDim2.new(0.8, 0, 0, 38)
	label.BackgroundTransparency = 0.12
	label.TextColor3 = Color3.fromRGB(255, 245, 235)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = screen

	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(370, 38)
	size.Parent = label
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MaxTextSize = 19
	textSize.Parent = label

	connection = stateChanged.OnClientEvent:Connect(function(snapshot: Snapshot)
		local alarm = snapshot.State == "Running" and snapshot.AlarmActive
		local landing = snapshot.State == "Running" and snapshot.DropPodState == "Warning"
		if alarm then
			label.Text = "FINAL RUSH  /  ALERT"
			label.BackgroundColor3 = Color3.fromRGB(120, 20, 33)
		elseif landing then
			label.Text = "WARNING  /  INCOMING DROP POD"
			label.BackgroundColor3 = Color3.fromRGB(116, 53, 17)
		end
		screen.Enabled = alarm or landing
	end)
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function StageAlertController.Destroy()
	if connection then connection:Disconnect(); connection = nil end
	if gui then gui:Destroy(); gui = nil end
end

return StageAlertController
