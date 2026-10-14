--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local InputController = require(script.Parent:WaitForChild("InputController"))

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CameraConfig"))
local RENDER_BINDING = "NeonBreakerCamera"
local CameraController = {}
local connections: { RBXScriptConnection } = {}
local started = false
local focused = true
local aiming = false
local trackedRoot: BasePart? = nil
local savedCamera: Camera? = nil
local savedCameraType = Enum.CameraType.Custom
local savedFieldOfView = 70
local savedMouseBehavior = Enum.MouseBehavior.Default
local savedMouseIconEnabled = true
local yaw = 0
local pitch = math.rad(Config.InitialPitch)
local distance = Config.NormalDistance
local shoulder = Config.NormalShoulderOffset
local fieldOfView = Config.NormalFieldOfView
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.RespectCanCollide = true

local function InputBlocked(): boolean
	return not focused or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
end

local function ReleaseMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function RestoreCamera()
	local camera = savedCamera
	if camera then
		camera.CameraType = savedCameraType
		camera.FieldOfView = savedFieldOfView
	end
	savedCamera = nil
end

local function Update(deltaTime: number)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local camera = Workspace.CurrentCamera
	if not camera or not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		aiming = false
		trackedRoot = nil
		ReleaseMouse()
		RestoreCamera()
		return
	end

	if camera ~= savedCamera then
		RestoreCamera()
		savedCamera = camera
		savedCameraType = camera.CameraType
		savedFieldOfView = camera.FieldOfView
	end
	if root ~= trackedRoot then
		trackedRoot = root
		local direction = root.CFrame.LookVector
		yaw = math.atan2(-direction.X, -direction.Z)
		pitch = math.rad(Config.InitialPitch)
		aiming = false
		distance = Config.NormalDistance
		shoulder = Config.NormalShoulderOffset
		fieldOfView = Config.NormalFieldOfView
		raycastParams.FilterDescendantsInstances = { character }
	end

	if InputBlocked() then
		aiming = false
		ReleaseMouse()
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		local delta = UserInputService:GetMouseDelta()
		yaw = (yaw - math.rad(delta.X * Config.MouseSensitivity)) % (2 * math.pi)
		pitch = math.clamp(pitch - math.rad(delta.Y * Config.MouseSensitivity), math.rad(Config.MinPitch), math.rad(Config.MaxPitch))
	end

	local alpha = 1 - math.exp(-Config.TransitionSpeed * deltaTime)
	local targetDistance = if aiming then Config.AimDistance else Config.NormalDistance
	local targetShoulder = if aiming then Config.AimShoulderOffset else Config.NormalShoulderOffset
	local targetFov = if aiming then Config.AimFieldOfView else Config.NormalFieldOfView
	distance += (targetDistance - distance) * alpha
	shoulder += (targetShoulder - shoulder) * alpha
	fieldOfView += (targetFov - fieldOfView) * alpha

	local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local pivot = root.Position + Vector3.new(0, Config.PivotHeight, 0)
	local offset = rotation:VectorToWorldSpace(Vector3.new(shoulder, 0, distance))
	-- Basic wall avoidance; exclude the local character from the camera ray.
	local hit = Workspace:Raycast(pivot, offset, raycastParams)
	if hit then
		offset = offset.Unit * math.max(0, hit.Distance - Config.CollisionPadding)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(pivot + offset) * rotation
	camera.Focus = CFrame.new(pivot)
	camera.FieldOfView = fieldOfView
end

function CameraController.Init()
	if started then
		return
	end
	assert(RunService:IsClient(), "CameraController must run on the client")
	started = true
	focused = true
	savedMouseBehavior = UserInputService.MouseBehavior
	savedMouseIconEnabled = UserInputService.MouseIconEnabled

	table.insert(connections, InputController.Aim:Connect(function(isHeld: boolean)
		aiming = isHeld and not InputBlocked()
	end))
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		aiming = false
		ReleaseMouse()
	end))
	table.insert(connections, UserInputService.WindowFocused:Connect(function()
		focused = true
	end))
	RunService:BindToRenderStep(RENDER_BINDING, Enum.RenderPriority.Camera.Value + 1, Update)
end

function CameraController.Destroy()
	if not started then
		return
	end
	started = false
	RunService:UnbindFromRenderStep(RENDER_BINDING)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	RestoreCamera()
	UserInputService.MouseBehavior = savedMouseBehavior
	UserInputService.MouseIconEnabled = savedMouseIconEnabled
	trackedRoot = nil
	aiming = false
end

return CameraController
