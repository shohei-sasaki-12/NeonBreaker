--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CombatConfig"))

local CombatValidation = {}

function CombatValidation.IsFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function CombatValidation.IsSequenceId(value: any): boolean
	return typeof(value) == "number" and CombatValidation.IsFinite(value)
		and value > 0 and value <= 9007199254740991 and value % 1 == 0
end

function CombatValidation.IsVector(value: any): boolean
	return typeof(value) == "Vector3" and CombatValidation.IsFinite(value.X)
		and CombatValidation.IsFinite(value.Y) and CombatValidation.IsFinite(value.Z)
end

function CombatValidation.IsDirection(value: any): boolean
	return CombatValidation.IsVector(value)
		and math.abs(value.Magnitude - 1) <= Config.DirectionMagnitudeTolerance
end

function CombatValidation.GetLivingRoot(player: Player, character: Model?): BasePart?
	if not character or player.Character ~= character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

return CombatValidation
