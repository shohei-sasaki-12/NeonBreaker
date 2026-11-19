--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CoreTitanConfig"))
local EnemyAI = script.Parent.Parent:WaitForChild("EnemyAI")
local Base = require(EnemyAI:WaitForChild("BaseEnemyAI"))
local MeleeAI = require(EnemyAI:WaitForChild("MeleeAI"))
local Projectiles = require(EnemyAI:WaitForChild("EnemyProjectiles"))
local Attacks = require(script.Parent:WaitForChild("CoreTitanAttacks"))
local Rig = require(script.Parent:WaitForChild("CoreTitanRig"))

type Dependencies = {
	Targets: () -> { Attacks.Target },
	Damage: (Player, number) -> boolean,
	Summon: (Vector3) -> (),
	Notify: () -> (),
}
type Attack = { Name: string, Start: (Attacks.Context, Attacks.Target) -> Attacks.Action, ExposesCore: boolean? }

local gatling: Attack = { Name = "GatlingLaser", Start = Attacks.Gatling }
local missile: Attack = { Name = "MissileRain", Start = Attacks.MissileRain }
local sweep: Attack = { Name = "ArmSweep", Start = Attacks.ArmSweep, ExposesCore = true }
local rotation: Attack = { Name = "RotatingLaser", Start = function(ctx) return Attacks.RotatingLaser(ctx) end }
local drones: Attack = { Name = "DroneSummon", Start = Attacks.DroneSummon }
local wall: Attack = { Name = "EnergyWall", Start = Attacks.EnergyWall }
local overload: Attack = { Name = "Overload", Start = Attacks.Overload, ExposesCore = true }
local charge: Attack = { Name = "HighSpeedCharge", Start = Attacks.HighSpeedCharge, ExposesCore = true }
local combined: Attack = { Name = "CombinedAttack", Start = Attacks.CombinedAttack }
local rotations = {
	{ gatling, missile, sweep },
	{ rotation, drones, wall, gatling, missile, sweep },
	{ overload, charge, combined, rotation, drones, wall, gatling, missile, sweep },
}

local CoreTitanAI = {}

function CoreTitanAI.new(model: Model, deps: Dependencies): MeleeAI.Controller
	local base = Base.new(model)
	local core = Rig.Build(model, base.Root)
	local parts: { Part } = {}
	local phase, cursor = 1, 1
	local nextAttackAt = 0
	local exposedUntil = 0
	local action: Attacks.Action? = nil
	local attack: Attack? = nil
	local active = true
	model:SetAttribute("BossPhase", phase)
	model:SetAttribute("CoreExposed", false)

	local function SetCore(exposed: boolean)
		if core.CanQuery == exposed then return end
		core.Transparency = if exposed then 0 else 1
		core.CanQuery = exposed
		model:SetAttribute("CoreExposed", exposed)
		deps.Notify()
	end

	local function ClearAttack()
		action, attack = nil, nil
		for _, part in parts do part:Destroy() end
		table.clear(parts)
		model:SetAttribute("BossAttack", nil)
	end

	return {
		Update = function(now: number)
			if not active or not Base.IsAlive(base) then return end
			local fraction = base.Humanoid.Health / base.Humanoid.MaxHealth
			local healthPhase = if fraction <= Config.Phase3At then 3 elseif fraction <= Config.Phase2At then 2 else 1
			if healthPhase > phase then
				phase, cursor = healthPhase, 1
				ClearAttack()
				Projectiles.ClearOwner(model)
				nextAttackAt = math.max(exposedUntil, now + Config.Recovery[phase])
				model:SetAttribute("BossPhase", phase)
				deps.Notify()
			end
			if exposedUntil > 0 and now >= exposedUntil then
				exposedUntil = 0
				SetCore(false)
			end
			local running, current = action, attack
			if running and current then
				if running(now) then
					ClearAttack()
					nextAttackAt = now + Config.Recovery[phase]
					if current.ExposesCore then
						exposedUntil = now + Config.ExposureDuration
						nextAttackAt = math.max(nextAttackAt, exposedUntil)
						SetCore(true)
					end
				end
				return
			end
			if now < nextAttackAt then return end

			local nearest: Attacks.Target? = nil
			local distance = math.huge
			local position = base.Root.Position
			for _, target in deps.Targets() do
				local offset = target.Root.Position - position
				local range = Vector2.new(offset.X, offset.Z).Magnitude
				if range < distance then nearest, distance = target, range end
			end
			if not nearest then Base.StopMovement(base); return end
			local choices = rotations[phase]
			local selected = choices[cursor]
			if distance > Config.Gatling.Range * 0.75 then
				base.Humanoid:MoveTo(nearest.Root.Position)
				return
			end
			if selected == sweep and distance > Config.Sweep.Radius then
				-- Use a ranged attack while the players keep their distance.
				selected = missile
			end
			Base.StopMovement(base)
			local targetPosition = nearest.Root.Position
			if distance > 0.01 then
				base.Root.CFrame = CFrame.lookAt(position, Vector3.new(targetPosition.X, position.Y, targetPosition.Z))
			end
			cursor = cursor % #choices + 1
			attack = selected
			model:SetAttribute("BossAttack", selected.Name)
			action = selected.Start({
				Model = model, Root = base.Root, Frame = base.Root.CFrame, StartedAt = now, Parts = parts,
				Targets = deps.Targets, Damage = deps.Damage, Summon = deps.Summon,
			}, nearest)
		end,
		Destroy = function()
			if not active then return end
			active = false
			ClearAttack()
			Projectiles.ClearOwner(model)
			Base.StopMovement(base)
		end,
	}
end

return CoreTitanAI
