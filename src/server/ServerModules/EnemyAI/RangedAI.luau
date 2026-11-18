--!strict

local EnemyConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyConfig"))
local Base = require(script.Parent:WaitForChild("BaseEnemyAI"))
local Projectiles = require(script.Parent:WaitForChild("EnemyProjectiles"))
local MeleeAI = require(script.Parent:WaitForChild("MeleeAI"))
local RangedAI = {}

function RangedAI.new(model: Model, config: EnemyConfig.EnemyDefinition, damagePlayer: (Player, number) -> boolean): MeleeAI.Controller
	local state = Base.new(model)
	local ranged = assert(config.Ranged)
	local nextShot = 0
	return {
		Update = function(now)
			local target = Base.GetTarget(state, now)
			if not target then Base.StopMovement(state); return end
			local offset = target.Root.Position - state.Root.Position
			local distance = offset.Magnitude
			local horizontal = Vector3.new(offset.X, 0, offset.Z)
			local visible = Base.HasLineOfSight(state, target)
			if distance < ranged.MinDistance and horizontal.Magnitude > 0 then
				state.Humanoid:MoveTo(state.Root.Position - horizontal.Unit * ranged.MinDistance)
			elseif distance > ranged.MaxDistance or not visible then
				state.Humanoid:MoveTo(target.Root.Position)
			else
				Base.StopMovement(state)
				if horizontal.Magnitude > 0 then
					state.Root.CFrame = CFrame.lookAt(state.Root.Position, state.Root.Position + horizontal)
				end
			end
			if visible and distance <= config.AttackRange and now >= nextShot then
				nextShot = now + config.AttackCooldown
				Projectiles.Fire(state.Root.Position, offset, ranged.ProjectileSpeed, config.AttackRange, config.Damage, damagePlayer)
			end
		end,
		Destroy = function() Base.StopMovement(state) end,
	}
end

return RangedAI
