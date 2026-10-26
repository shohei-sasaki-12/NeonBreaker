--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local InputController = require(script.Parent:WaitForChild("InputController"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SpecialEquipmentConfig"))

local SpecialEquipmentController = {}
local connections: { RBXScriptConnection } = {}
local started = false

function SpecialEquipmentController.Init()
	if started then return end
	assert(RunService:IsClient(), "SpecialEquipmentController must run on the client")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat"):WaitForChild("UseSpecial")
	assert(remote:IsA("RemoteEvent"), "UseSpecial must be a RemoteEvent")
	if started then return end
	started = true
	local nextRequestAt = 0
	table.insert(connections, InputController.SpecialEquipment:Connect(function()
		local now = os.clock()
		if now < nextRequestAt then return end
		nextRequestAt = now + Config.RequestInterval
		local camera = Workspace.CurrentCamera
		local direction: Vector3? = nil
		if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
			local viewport = camera.ViewportSize
			direction = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2).Direction.Unit
		end
		remote:FireServer(direction)
	end))
	table.insert(connections, remote.OnClientEvent:Connect(function(result)
		print("[SpecialEquipment] " .. result.Reason)
	end))
end

function SpecialEquipmentController.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

return SpecialEquipmentController
