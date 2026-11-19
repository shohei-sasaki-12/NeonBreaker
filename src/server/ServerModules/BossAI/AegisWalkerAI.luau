--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local AI = script.Parent.Parent:WaitForChild("EnemyAI")
local Base = require(AI:WaitForChild("BaseEnemyAI"))
local MeleeAI = require(AI:WaitForChild("MeleeAI"))
local Attacks = require(AI:WaitForChild("EnemyAttacks"))
local Projectiles = require(AI:WaitForChild("EnemyProjectiles"))
local Rig = require(script.Parent:WaitForChild("AegisWalkerRig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AegisWalkerConfig"))

type Missile = { Position: Vector3, Warning: Part, Body: Part, ImpactAt: number }
type Dependencies = {
	GetLiving: () -> { Player },
	IsLiving: (Player) -> boolean,
	Damage: Attacks.DamagePlayer,
	Summon: (Vector3, { Player }) -> (),
}
local ORANGE = Color3.fromRGB(255, 105, 50)
local RED = Color3.fromRGB(255, 52, 75)
local AegisWalkerAI = {}

local function RootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function Nearest(position: Vector3, players: { Player }): (Player?, BasePart?, number)
	local nearest: Player? = nil
	local nearestRoot: BasePart? = nil
	local distance = math.huge
	for _, player in players do
		local root = RootOf(player)
		if root then
			local candidateDistance = (root.Position - position).Magnitude
			if candidateDistance < distance then
				nearest, nearestRoot, distance = player, root, candidateDistance
			end
		end
	end
	return nearest, nearestRoot, distance
end

local function Face(root: BasePart, position: Vector3)
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude > 0.01 then root.CFrame = CFrame.lookAt(root.Position, flat) end
end

local function Muzzle(root: BasePart): Vector3
	return root.CFrame:PointToWorldSpace(Vector3.new(0, 2.95, -4.3))
end

function AegisWalkerAI.new(model: Model, dependencies: Dependencies): MeleeAI.Controller
	local base = Base.new(model)
	local leg = Rig.Build(model, base.Root)
	local legRest = leg.C0
	local laser: Part? = nil
	local lockedPlayer: Player? = nil
	local aim: Vector3? = nil
	local gunStarts, gunEnds, nextShot, lastAimUpdate = 0, 0, 0, 0
	local prefersMissiles = false
	local missiles: { Missile } = {}
	local stompAt: number? = nil
	local stompCenter: Vector3? = nil
	local stompMarker: Part? = nil
	local shockwave: Part? = nil
	local stompHit: { [Player]: boolean } = {}
	local availableAt = os.clock() + Config.AttackRecovery
	local nextSummon = os.clock() + Config.Reinforcement.Interval
	local active = true

	local function Damage(player: Player, amount: number): boolean
		return active and dependencies.IsLiving(player) and dependencies.Damage(player, amount)
	end

	local function StopGun()
		if laser then laser:Destroy() end
		laser, lockedPlayer, aim = nil, nil, nil
	end

	local function StopStomp()
		if stompMarker then stompMarker:Destroy() end
		if shockwave then shockwave:Destroy() end
		stompMarker, shockwave, stompAt, stompCenter = nil, nil, nil, nil
		leg.C0 = legRest
		table.clear(stompHit)
	end

	local function UpdateGun(now: number): boolean
		local targetPlayer, tracked, beam = lockedPlayer, aim, laser
		if not targetPlayer or not tracked or not beam then return false end
		local root = if dependencies.IsLiving(targetPlayer) then RootOf(targetPlayer) else nil
		if not root or now >= gunEnds then
			StopGun()
			availableAt = now + Config.AttackRecovery
			return false
		end
		local alpha = 1 - math.exp(-Config.TrackingRate * (now - lastAimUpdate))
		lastAimUpdate = now
		tracked = tracked:Lerp(root.Position, alpha)
		aim = tracked
		Face(base.Root, tracked)
		local start = Muzzle(base.Root)
		local direction = tracked - start
		if direction.Magnitude < 0.01 then return true end
		local ray = Workspace:Raycast(start, direction.Unit * math.min(direction.Magnitude, Config.Gun.Range), Attacks.RaycastParams(targetPlayer.Character))
		local endpoint = if ray then ray.Position else start + direction.Unit * math.min(direction.Magnitude, Config.Gun.Range)
		local distance = math.max((endpoint - start).Magnitude, 0.05)
		beam.Size = Vector3.new(0.11, 0.11, distance)
		beam.CFrame = CFrame.lookAt(start, start + direction) * CFrame.new(0, 0, -distance / 2)
		if now >= gunStarts and now >= nextShot then
			nextShot = now + Config.Gun.Interval
			Projectiles.Fire(start, direction, Config.Gun.Speed, Config.Gun.Range, Config.Gun.Damage, Damage, model)
		end
		return true
	end

	local function StartMissiles(now: number, living: { Player })
		for _, player in living do
			local root = RootOf(player)
			if not root then continue end
			local position = root.Position
			local delayTime = Config.Missile.Windup + #missiles * Config.Missile.Stagger
			local warning = Attacks.ShowArea(position, Config.Missile.Radius, delayTime + 1, RED)
			local body = Attacks.MakeVisual("AegisMissile", ORANGE, Vector3.new(0.65, 2.8, 0.65))
			body.Position = position + Vector3.new(0, Config.Missile.FallHeight, 0)
			body.Parent = Workspace
			table.insert(missiles, { Position = position, Warning = warning, Body = body, ImpactAt = now + delayTime })
		end
	end

	local function UpdateMissiles(now: number): boolean
		if #missiles == 0 then return false end
		for i = #missiles, 1, -1 do
			local missile = missiles[i]
			if now >= missile.ImpactAt then
				table.remove(missiles, i)
				missile.Warning:Destroy()
				missile.Body:Destroy()
				Attacks.ShowArea(missile.Position, Config.Missile.Radius, 0.2, ORANGE)
				Attacks.DamageArea(missile.Position, Config.Missile.Radius, Config.Missile.Damage, Damage)
			else
				local height = Config.Missile.FallHeight * math.clamp((missile.ImpactAt - now) / Config.Missile.Windup, 0, 1)
				missile.Body.Position = missile.Position + Vector3.new(0, height, 0)
			end
		end
		if #missiles == 0 then availableAt = now + Config.AttackRecovery end
		return true
	end

	local function UpdateStomp(now: number): boolean
		local impact, position = stompAt, stompCenter
		if not impact or not position then return false end
		if now < impact then return true end
		local wave = shockwave
		if not wave then
			if stompMarker then stompMarker:Destroy(); stompMarker = nil end
			leg.C0 = legRest
			wave = Attacks.ShowArea(position, 0.2, Config.Stomp.WaveDuration + 1, ORANGE)
			wave.Name = "AegisShockwave"
			shockwave = wave
		end
		local progress = math.clamp((now - impact) / Config.Stomp.WaveDuration, 0, 1)
		local radius = math.max(0.2, Config.Stomp.Radius * progress)
		wave.Size = Vector3.new(0.17, radius * 2, radius * 2)
		Attacks.DamageArea(position, radius, Config.Stomp.Damage, function(player, amount)
			if stompHit[player] or not Damage(player, amount) then return false end
			stompHit[player] = true
			return true
		end)
		if progress >= 1 then
			StopStomp()
			availableAt = now + Config.AttackRecovery
		end
		return true
	end

	return {
		Update = function(now)
			if not active or not Base.IsAlive(base) then return end
			if UpdateStomp(now) or UpdateMissiles(now) or UpdateGun(now) then return end
			local living = dependencies.GetLiving()
			local player, root, distance = Nearest(base.Root.Position, living)
			if not player or not root then Base.StopMovement(base); return end
			if distance > Config.Gun.Range then
				base.Humanoid:MoveTo(root.Position)
				return
			end
			Base.StopMovement(base)
			if now < availableAt then return end
			Face(base.Root, root.Position)
			if now >= nextSummon then
				nextSummon = now + Config.Reinforcement.Interval
				dependencies.Summon(base.Root.Position, living)
				availableAt = now + Config.AttackRecovery
			elseif distance <= Config.Stomp.TriggerRange then
				local center = base.Root.Position
				stompAt, stompCenter = now + Config.Stomp.Windup, center
				leg.C0 = legRest * CFrame.new(0, 1.4, 0)
				stompMarker = Attacks.ShowArea(center, Config.Stomp.Radius, Config.Stomp.Windup + 1, RED)
			elseif prefersMissiles then
				prefersMissiles = false
				StartMissiles(now, living)
			else
				prefersMissiles = true
				lockedPlayer, aim, lastAimUpdate = player, root.Position, now
				gunStarts = now + Config.Gun.Windup
				gunEnds, nextShot = gunStarts + Config.Gun.Duration, gunStarts
				local beam = Attacks.MakeVisual("AegisAimLaser", RED, Vector3.one * 0.11)
				beam.Position = Muzzle(base.Root)
				beam.Parent = Workspace
				laser = beam
				UpdateGun(now)
			end
		end,
		Destroy = function()
			active = false
			StopGun()
			StopStomp()
			for _, missile in missiles do missile.Warning:Destroy(); missile.Body:Destroy() end
			table.clear(missiles)
			Projectiles.ClearOwner(model)
			Base.StopMovement(base)
		end,
	}
end

return AegisWalkerAI
