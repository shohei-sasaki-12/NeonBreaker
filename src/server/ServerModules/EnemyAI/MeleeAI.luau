--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyConfig"))
local BaseEnemyAI = require(script.Parent:WaitForChild("BaseEnemyAI"))

export type Controller = {
	Update: (now: number) -> (),
	Destroy: () -> (),
}

local MeleeAI = {}

function MeleeAI.new(model: Model, config: EnemyConfig.EnemyDefinition, damagePlayer: (Player, number) -> boolean): Controller
	local base = BaseEnemyAI.new(model)
	local nextAttackAt = 0
	local active = true

	return {
		Update = function(now: number)
			if not active or not BaseEnemyAI.IsAlive(base) then
				return
			end
			local target = BaseEnemyAI.GetTarget(base, now)
			if not target then
				BaseEnemyAI.StopMovement(base)
				return
			end
			local distance = (target.Root.Position - base.Root.Position).Magnitude
			if distance > config.AttackRange then
				base.Humanoid:MoveTo(target.Root.Position)
				return
			end
			BaseEnemyAI.StopMovement(base)
			if now >= nextAttackAt and BaseEnemyAI.HasLineOfSight(base, target) then
				-- One cooldown per enemy, including when switching targets.
				nextAttackAt = now + config.AttackCooldown
				damagePlayer(target.Player, config.Damage)
			end
		end,
		Destroy = function()
			if not active then
				return
			end
			active = false
			base.Target = nil
			BaseEnemyAI.StopMovement(base)
		end,
	}
end

return MeleeAI
