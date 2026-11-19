--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local InputController = require(script.Parent:WaitForChild("InputController"))
local DashController = {}
local connection: RBXScriptConnection? = nil

function DashController.Init()
	if connection then return end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat"):WaitForChild("Dash")
	assert(remote:IsA("RemoteEvent"), "Dash must be a RemoteEvent")
	connection = InputController.Dash:Connect(function()
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local camera = Workspace.CurrentCamera
		if not humanoid or humanoid.Health <= 0 or not camera then return end
		local movement = humanoid.MoveDirection
		local direction = if movement.Magnitude > 0.05 then movement else camera.CFrame.LookVector
		local horizontal = Vector3.new(direction.X, 0, direction.Z)
		if horizontal.Magnitude > 0.05 then remote:FireServer(horizontal.Unit) end
	end)
end

function DashController.Destroy()
	if connection then connection:Disconnect(); connection = nil end
end

return DashController
