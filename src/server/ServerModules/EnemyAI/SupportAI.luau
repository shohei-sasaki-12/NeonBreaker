--!strict

local EnemyConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyConfig"))
local Base = require(script.Parent:WaitForChild("BaseEnemyAI"))
local MeleeAI = require(script.Parent:WaitForChild("MeleeAI"))
local SupportAI = {}

function SupportAI.new(model: Model, config: EnemyConfig.EnemyDefinition, query: (Vector3, number) -> { Model }, heal: (Model, number) -> boolean): MeleeAI.Controller
	local state = Base.new(model)
	local support = assert(config.Support)
	local nextHeal = 0
	return {
		Update = function(now)
			local target = Base.GetTarget(state, now)
			if target then
				local offset = state.Root.Position - target.Root.Position
				local horizontal = Vector3.new(offset.X, 0, offset.Z)
				if horizontal.Magnitude < support.RetreatDistance then
					local away = if horizontal.Magnitude > 0 then horizontal.Unit else -state.Root.CFrame.LookVector
					state.Humanoid:MoveTo(state.Root.Position + away * support.RetreatDistance)
				else
					Base.StopMovement(state)
				end
			else
				Base.StopMovement(state)
			end
			if now < nextHeal then return end
			nextHeal = now + config.AttackCooldown
			for _, ally in query(state.Root.Position, support.Radius) do
				if ally ~= model then heal(ally, support.Heal) end
			end
		end,
		Destroy = function() Base.StopMovement(state) end,
	}
end

return SupportAI
