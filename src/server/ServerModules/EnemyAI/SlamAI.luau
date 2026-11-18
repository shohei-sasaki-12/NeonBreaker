--!strict

local EnemyConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyConfig"))
local Base = require(script.Parent:WaitForChild("BaseEnemyAI"))
local Attacks = require(script.Parent:WaitForChild("EnemyAttacks"))
local MeleeAI = require(script.Parent:WaitForChild("MeleeAI"))
local SlamAI = {}

function SlamAI.new(model: Model, config: EnemyConfig.EnemyDefinition, damagePlayer: Attacks.DamagePlayer): MeleeAI.Controller
	local state = Base.new(model)
	local slam = assert(config.Slam)
	local nextAttack = 0
	local impactAt = 0
	local center: Vector3? = nil
	local marker: Part? = nil
	local function Cancel()
		center = nil
		if marker then marker:Destroy(); marker = nil end
	end
	return {
		Update = function(now)
			if center then
				if now < impactAt then return end
				local position = center
				Cancel()
				Attacks.DamageArea(position, slam.Radius, config.Damage, damagePlayer)
				return
			end
			local target = Base.GetTarget(state, now)
			if not target then Base.StopMovement(state); return end
			if (target.Root.Position - state.Root.Position).Magnitude > config.AttackRange then
				state.Humanoid:MoveTo(target.Root.Position)
				return
			end
			Base.StopMovement(state)
			if now >= nextAttack and Base.HasLineOfSight(state, target) then
				local position = state.Root.Position
				center = position
				impactAt = now + slam.Windup
				nextAttack = impactAt + config.AttackCooldown
				marker = Attacks.ShowArea(position, slam.Radius, slam.Windup + config.AttackCooldown, Color3.fromRGB(255, 95, 55))
			end
		end,
		Interrupt = Cancel,
		Destroy = function()
			Cancel()
			Base.StopMovement(state)
		end,
	}
end

return SlamAI
