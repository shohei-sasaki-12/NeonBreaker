--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyAIConfig"))

export type Target = {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
}

export type State = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Target: Target?,
	NextSearchAt: number,
}

local BaseEnemyAI = {}

function BaseEnemyAI.new(model: Model): State
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and root:IsA("BasePart"), "Enemy requires a Humanoid and HumanoidRootPart")
	return { Model = model, Humanoid = humanoid, Root = root, Target = nil, NextSearchAt = 0 }
end

function BaseEnemyAI.IsAlive(state: State): boolean
	return state.Model.Parent ~= nil and state.Humanoid.Parent == state.Model
		and state.Root.Parent == state.Model and state.Humanoid.Health > 0
end

local function IsValidTarget(target: Target): boolean
	return target.Player.Parent == Players and target.Player.Character == target.Character
		and target.Character.Parent ~= nil and target.Humanoid.Parent == target.Character
		and target.Root.Parent == target.Character and target.Humanoid.Health > 0
end

function BaseEnemyAI.GetTarget(state: State, now: number): Target?
	local current = state.Target
	if now >= state.NextSearchAt or (current ~= nil and not IsValidTarget(current)) then
		state.NextSearchAt = now + Config.TargetSearchInterval
		local nearest: Target? = nil
		local nearestDistance = math.huge
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if character and character.Parent and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				local distance = (root.Position - state.Root.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearest = { Player = player, Character = character, Humanoid = humanoid, Root = root }
				end
			end
		end
		state.Target = nearest
	end
	return state.Target
end

function BaseEnemyAI.StopMovement(state: State)
	if state.Humanoid.Parent and state.Root.Parent then
		state.Humanoid:MoveTo(state.Root.Position)
	end
end

function BaseEnemyAI.HasLineOfSight(state: State, target: Target): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.Model, target.Character }
	local offset = target.Root.Position - state.Root.Position
	return offset.Magnitude == 0 or Workspace:Raycast(state.Root.Position, offset, params) == nil
end

return BaseEnemyAI
