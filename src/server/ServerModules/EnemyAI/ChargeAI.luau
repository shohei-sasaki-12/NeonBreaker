--!strict

local EnemyConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyConfig"))
local Base = require(script.Parent:WaitForChild("BaseEnemyAI"))
local MeleeAI = require(script.Parent:WaitForChild("MeleeAI"))
local ChargeAI = {}

function ChargeAI.new(model: Model, config: EnemyConfig.EnemyDefinition, damagePlayer: (Player, number) -> boolean): MeleeAI.Controller
	local state = Base.new(model)
	local charge = assert(config.Charge)
	local nextAttack = 0
	local windupEnd = 0
	local chargeEnd = 0
	local goal: Vector3? = nil
	local normalSpeed = config.MoveSpeed
	local dashSpeed: number? = nil
	local flash = Instance.new("Highlight")
	flash.Name = "ChargeWarning"
	flash.FillColor = Color3.fromRGB(255, 50, 50)
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Enabled = false
	flash.Parent = model

	local function Cancel()
		if not goal then return end
		if dashSpeed and state.Humanoid.WalkSpeed == dashSpeed then
			state.Humanoid.WalkSpeed = normalSpeed
		end
		goal, dashSpeed = nil, nil
		flash.Enabled = false
		Base.StopMovement(state)
	end

	return {
		Update = function(now)
			local target = Base.GetTarget(state, now)
			local lockedGoal = goal
			if lockedGoal then
				if now < windupEnd then return end
				if now >= chargeEnd then Cancel(); return end
				if not dashSpeed then
					flash.Enabled = false
					normalSpeed = state.Humanoid.WalkSpeed
					local speed = normalSpeed * charge.SpeedMultiplier
					dashSpeed = speed
					state.Humanoid.WalkSpeed = speed
					state.Humanoid:MoveTo(lockedGoal)
				end
				if target and (target.Root.Position - state.Root.Position).Magnitude <= config.AttackRange
					and Base.HasLineOfSight(state, target) then
					Cancel()
					damagePlayer(target.Player, config.Damage)
				end
				return
			end
			if not target then Base.StopMovement(state); return end
			local distance = (target.Root.Position - state.Root.Position).Magnitude
			if now >= nextAttack and distance <= charge.Range and Base.HasLineOfSight(state, target) then
				if distance >= charge.MinDistance then
					Base.StopMovement(state)
					goal = target.Root.Position
					windupEnd = now + charge.Windup
					chargeEnd = windupEnd + charge.Duration
					nextAttack = chargeEnd + config.AttackCooldown
					flash.Enabled = true
					return
				elseif distance <= config.AttackRange then
					Base.StopMovement(state)
					nextAttack = now + config.AttackCooldown
					damagePlayer(target.Player, config.Damage)
					return
				end
			end
			if distance > config.AttackRange then state.Humanoid:MoveTo(target.Root.Position) else Base.StopMovement(state) end
		end,
		Interrupt = Cancel,
		Destroy = function()
			Cancel()
			flash:Destroy()
			Base.StopMovement(state)
		end,
	}
end

return ChargeAI
