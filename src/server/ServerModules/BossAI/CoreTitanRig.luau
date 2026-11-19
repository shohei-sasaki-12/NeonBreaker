--!strict

local CoreTitanRig = {}

function CoreTitanRig.Build(model: Model, root: BasePart): BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.Transparency = 1 end
	end
	local function Attach(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = root.CFrame * CFrame.new(offset)
		part.CanCollide = false
		part.CanTouch = false
		part.Massless = true
		part.Material = Enum.Material.Metal
		part.Color = color
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, part
		weld.Parent = part
		part.Parent = model
		return part
	end
	local armor = Color3.fromRGB(66, 77, 104)
	local joint = Color3.fromRGB(38, 45, 63)
	Attach("TorsoArmor", Vector3.new(11, 7, 6), Vector3.new(0, 1.3, 0), armor)
	Attach("CommandHead", Vector3.new(5, 3, 4), Vector3.new(0, 6.1, -0.5), joint)
	for _, side in { -1, 1 } do
		Attach("Arm", Vector3.new(3.3, 8, 4), Vector3.new(side * 7, 0.5, 0), armor)
		Attach("Leg", Vector3.new(3.6, 6, 4), Vector3.new(side * 3.3, -4, 0), joint)
	end
	local core = Attach("TitanCore", Vector3.new(2.8, 2.8, 1), Vector3.new(0, 2, -3.6), Color3.fromRGB(255, 117, 50))
	core.Material = Enum.Material.Neon
	core.Transparency = 1
	core.CanQuery = false
	return core
end

return CoreTitanRig
