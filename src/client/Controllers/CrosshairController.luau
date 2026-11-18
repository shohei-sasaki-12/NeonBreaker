--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CameraController = require(script.Parent:WaitForChild("CameraController"))

local RENDER_BINDING = "NeonBreakerCrosshair"
local NORMAL_COLOR = Color3.fromRGB(240, 248, 255)
local AIM_COLOR = Color3.fromRGB(112, 245, 255)
local OUTLINE_COLOR = Color3.fromRGB(11, 18, 29)
local NORMAL_GAP = 6
local AIM_GAP = 4
local ARM_LENGTH = 7
local ARM_WIDTH = 2
local DOT_SIZE = 3

local gui: ScreenGui? = nil
local CrosshairController = {}

local function MakeMark(parent: Frame, name: string, width: number, height: number): (Frame, Frame)
	local outline = Instance.new("Frame")
	outline.Name = name
	outline.AnchorPoint = Vector2.new(0.5, 0.5)
	outline.Size = UDim2.fromOffset(width + 2, height + 2)
	outline.BorderSizePixel = 0
	outline.BackgroundColor3 = OUTLINE_COLOR
	outline.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Position = UDim2.fromOffset(1, 1)
	fill.Size = UDim2.fromOffset(width, height)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = NORMAL_COLOR
	fill.Parent = outline
	return outline, fill
end

function CrosshairController.Init()
	if gui then return end
	assert(RunService:IsClient(), "CrosshairController must run on the client")

	local screen = Instance.new("ScreenGui")
	screen.Name = "CrosshairUI"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.Enabled = false
	-- Match Camera.ViewportSize and ViewportPointToRay, including device cutouts.
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui = screen

	local center = Instance.new("Frame")
	center.Name = "Center"
	center.BackgroundTransparency = 1
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Parent = screen

	local left, leftFill = MakeMark(center, "Left", ARM_LENGTH, ARM_WIDTH)
	local right, rightFill = MakeMark(center, "Right", ARM_LENGTH, ARM_WIDTH)
	local top, topFill = MakeMark(center, "Top", ARM_WIDTH, ARM_LENGTH)
	local bottom, bottomFill = MakeMark(center, "Bottom", ARM_WIDTH, ARM_LENGTH)
	local _, dotFill = MakeMark(center, "Dot", DOT_SIZE, DOT_SIZE)
	local fills = { leftFill, rightFill, topFill, bottomFill, dotFill }
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local lastAiming: boolean? = nil
	RunService:BindToRenderStep(RENDER_BINDING, Enum.RenderPriority.Camera.Value + 2, function()
		local visible, aiming = CameraController.GetAimState()
		if screen.Enabled ~= visible then screen.Enabled = visible end
		if lastAiming == aiming then return end
		lastAiming = aiming
		local offset = (if aiming then AIM_GAP else NORMAL_GAP) + ARM_LENGTH / 2
		left.Position = UDim2.fromOffset(-offset, 0)
		right.Position = UDim2.fromOffset(offset, 0)
		top.Position = UDim2.fromOffset(0, -offset)
		bottom.Position = UDim2.fromOffset(0, offset)
		local color = if aiming then AIM_COLOR else NORMAL_COLOR
		for _, fill in fills do fill.BackgroundColor3 = color end
	end)
end

function CrosshairController.Destroy()
	local screen = gui
	if not screen then return end
	RunService:UnbindFromRenderStep(RENDER_BINDING)
	screen:Destroy()
	gui = nil
end

return CrosshairController
