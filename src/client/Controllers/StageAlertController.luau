--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Aegis = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AegisWalkerConfig"))

type Snapshot = {
	State: string, DropPodState: string?, AlarmActive: boolean,
	MidBossState: string?, BossHealth: number?, BossMaxHealth: number?,
}
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

	local bossPanel = Instance.new("Frame")
	bossPanel.Name = "BossHP"
	bossPanel.AnchorPoint = Vector2.new(0.5, 0)
	bossPanel.Position = UDim2.new(0.5, 0, 0, 62)
	bossPanel.Size = UDim2.new(0.82, 0, 0, 36)
	bossPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 31)
	bossPanel.BorderSizePixel = 0
	bossPanel.Visible = false
	bossPanel.Parent = screen
	local bossSize = Instance.new("UISizeConstraint")
	bossSize.MaxSize = Vector2.new(480, 36)
	bossSize.Parent = bossPanel

	local fill = Instance.new("Frame")
	fill.Name = "HealthFill"
	fill.Position = UDim2.fromScale(0, 0.81)
	fill.Size = UDim2.fromScale(1, 0.19)
	fill.BackgroundColor3 = Color3.fromRGB(245, 76, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bossPanel

	local bossLabel = Instance.new("TextLabel")
	bossLabel.Size = UDim2.new(1, 0, 0.81, 0)
	bossLabel.BackgroundTransparency = 1
	bossLabel.TextColor3 = label.TextColor3
	bossLabel.Font = Enum.Font.GothamBold
	bossLabel.TextSize = 14
	bossLabel.Parent = bossPanel

	connection = stateChanged.OnClientEvent:Connect(function(snapshot: Snapshot)
		local alarm = snapshot.State == "Running" and snapshot.AlarmActive
		local landing = snapshot.State == "Running" and snapshot.DropPodState == "Warning"
		local bossWarning = snapshot.State == "Running" and snapshot.MidBossState == "Warning"
		if alarm then
			label.Text = "FINAL RUSH  /  ALERT"
			label.BackgroundColor3 = Color3.fromRGB(120, 20, 33)
		elseif landing then
			label.Text = "WARNING  /  INCOMING DROP POD"
			label.BackgroundColor3 = Color3.fromRGB(116, 53, 17)
		elseif bossWarning then
			label.Text = "WARNING  /  " .. Aegis.DisplayName
			label.BackgroundColor3 = Color3.fromRGB(120, 20, 33)
		end
		local health, maximum = snapshot.BossHealth, snapshot.BossMaxHealth
		if snapshot.State == "Running" and snapshot.MidBossState == "Active" and health and maximum and maximum > 0 then
			bossPanel.Visible = true
			bossLabel.Text = string.format("%s   %d / %d", Aegis.DisplayName, math.ceil(health), math.ceil(maximum))
			fill.Size = UDim2.fromScale(math.clamp(health / maximum, 0, 1), 0.19)
		else
			bossPanel.Visible = false
		end
		label.Visible = alarm or landing or bossWarning
		screen.Enabled = label.Visible or bossPanel.Visible
	end)
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function StageAlertController.Destroy()
	if connection then connection:Disconnect(); connection = nil end
	if gui then gui:Destroy(); gui = nil end
end

return StageAlertController
