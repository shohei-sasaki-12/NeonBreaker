--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EnemyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EnemyConfig"))
local Elite = require(Shared:WaitForChild("Config"):WaitForChild("EliteConfig"))
local EnemyArmor = {}

export type Controller = {
	Absorb: (number, Vector3?) -> number,
	ApplyEMP: (number) -> (),
	Update: () -> (),
}

function EnemyArmor.new(model: Model, root: BasePart, shield: EnemyConfig.ShieldDefinition?, hasEliteShield: boolean): Controller
	local guardianValue = if shield then shield.Capacity else 0
	local eliteValue = if hasEliteShield then Elite.ShieldCapacity else 0
	local recoverAt = 0
	local plate: Part? = nil
	if shield then
		local part = Instance.new("Part")
		part.Name = "GuardianShield"
		part.Size = Vector3.new(3.3, 3.1, 0.2) * model:GetScale()
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(70, 205, 255)
		part.CFrame = root.CFrame * CFrame.new(0, 0, -1.2 * model:GetScale())
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, part
		weld.Parent = part
		part.Parent = model
		plate = part
		model:SetAttribute("GuardianShield", guardianValue)
	end
	if hasEliteShield then model:SetAttribute("EliteShield", eliteValue) end

	local function SetGuardian(value: number)
		guardianValue = value
		model:SetAttribute("GuardianShield", value)
		if plate then plate.Transparency = if value > 0 then 0.65 else 1 end
		if value == 0 and shield then recoverAt = os.clock() + shield.RecoveryTime end
	end

	local function Update()
		if shield and guardianValue == 0 and os.clock() >= recoverAt then
			SetGuardian(shield.Capacity)
		end
	end
	if shield then SetGuardian(guardianValue) end

	return {
		Update = Update,
		Absorb = function(amount, origin)
			Update()
			if shield and guardianValue > 0 and origin then
				local offset = origin - root.Position
				local forward = root.CFrame.LookVector
				local horizontal = Vector3.new(offset.X, 0, offset.Z)
				local facing = Vector3.new(forward.X, 0, forward.Z)
				if horizontal.Magnitude > 0 and facing.Magnitude > 0
					and facing.Unit:Dot(horizontal.Unit) >= math.cos(math.rad(shield.ArcDegrees / 2)) then
					local absorbed = math.min(amount, guardianValue)
					SetGuardian(guardianValue - absorbed)
					amount -= absorbed
				end
			end
			if eliteValue > 0 and amount > 0 then
				local absorbed = math.min(amount, eliteValue)
				eliteValue -= absorbed
				model:SetAttribute("EliteShield", eliteValue)
				amount -= absorbed
			end
			return amount
		end,
		ApplyEMP = function(amount)
			Update()
			if guardianValue > 0 then
				SetGuardian(math.max(0, guardianValue - amount))
			end
		end,
	}
end

return EnemyArmor
