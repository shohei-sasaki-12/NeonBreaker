--!strict

local AegisWalkerRig = {}
local ARMOR = Color3.fromRGB(54, 72, 90)
local JOINT = Color3.fromRGB(28, 38, 52)
local CORE = Color3.fromRGB(255, 118, 65)

local function Attach(model: Model, root: BasePart, name: string, size: Vector3, offset: Vector3, color: Color3): Motor6D
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * CFrame.new(offset)
	part.Color = color
	part.Material = if color == CORE then Enum.Material.Neon else Enum.Material.Metal
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	local joint = Instance.new("Motor6D")
	joint.Part0 = root
	joint.Part1 = part
	joint.C0 = CFrame.new(offset)
	joint.Parent = part
	part.Parent = model
	return joint
end

function AegisWalkerRig.Build(model: Model, root: BasePart): Motor6D
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.Transparency = 1 end
	end
	Attach(model, root, "Chassis", Vector3.new(7.6, 3.2, 6.2), Vector3.new(0, 1.1, 0), ARMOR)
	Attach(model, root, "Sensor", Vector3.new(3.6, 0.55, 0.35), Vector3.new(0, 1.8, -3.18), CORE)
	Attach(model, root, "Cannon", Vector3.new(0.85, 0.85, 3.8), Vector3.new(0, 2.95, -2.3), JOINT)
	local stompJoint: Motor6D? = nil
	for _, x in { -4, 4 } do
		for _, z in { -2.7, 2.7 } do
			local joint = Attach(model, root, "Leg", Vector3.new(1.65, 6, 1.8), Vector3.new(x, -2.35, z), ARMOR)
			stompJoint = stompJoint or joint
		end
	end
	return assert(stompJoint)
end

return AegisWalkerRig
