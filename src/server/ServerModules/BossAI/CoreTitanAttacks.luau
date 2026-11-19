--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AI = script.Parent.Parent:WaitForChild("EnemyAI")
local Visual = require(AI:WaitForChild("EnemyAttacks"))
local Projectiles = require(AI:WaitForChild("EnemyProjectiles"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CoreTitanConfig"))

export type Target = { Player: Player, Root: BasePart }
export type Context = {
	Model: Model, Root: BasePart, Frame: CFrame, StartedAt: number, Parts: { Part },
	Targets: () -> { Target }, Damage: Visual.DamagePlayer, Summon: (Vector3) -> (),
}
export type Action = (number) -> boolean -- true when the attack is complete
local Attacks = {}
local RED = Color3.fromRGB(255, 65, 82)
local ORANGE = Color3.fromRGB(255, 140, 53)
local SAFE = Color3.fromRGB(70, 255, 175)

local function Part(ctx: Context, name: string, size: Vector3, color: Color3): Part
	local marker = Visual.MakeVisual(name, color, size)
	table.insert(ctx.Parts, marker)
	marker.Parent = Workspace
	return marker
end

local function GroundBox(ctx: Context, name: string, x: number, z: number, width: number, length: number, color: Color3): Part
	local marker = Part(ctx, name, Vector3.new(width, 0.15, length), color)
	local frame = ctx.Frame * CFrame.new(x, 0, z)
	local ground = Workspace:Raycast(frame.Position, Vector3.new(0, -32, 0), Visual.RaycastParams(nil))
	local y = if ground then ground.Position.Y + 0.12 else frame.Position.Y - 4
	marker.CFrame = frame + Vector3.new(0, y - frame.Position.Y, 0)
	marker.Transparency = 0.45
	return marker
end

local function SafeLane(ctx: Context)
	local lane = Config.SafeLane
	GroundBox(ctx, "TitanSafeLane", lane.Offset, -lane.Length / 4, lane.Width, lane.Length, SAFE)
end

local function ClearShot(origin: Vector3, target: Target): boolean
	local offset = target.Root.Position - origin
	return offset.Magnitude == 0 or Workspace:Raycast(origin, offset, Visual.RaycastParams(target.Player.Character)) == nil
end

local function HitOnce(ctx: Context, hit: { [Player]: boolean }, amount: number, contains: (Vector3) -> boolean)
	for _, target in ctx.Targets() do
		if not hit[target.Player] and contains(ctx.Frame:PointToObjectSpace(target.Root.Position))
			and ClearShot(ctx.Frame.Position, target) and ctx.Damage(target.Player, amount) then
			hit[target.Player] = true
		end
	end
end

local function Beam(part: Part, from: Vector3, to: Vector3, width: number)
	local length = (to - from).Magnitude
	if length < 0.01 then part.Transparency = 1; return end
	part.Transparency = 0.15
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
end

function Attacks.Gatling(ctx: Context, target: Target): Action
	local config = Config.Gatling
	local laser = Part(ctx, "TitanGatlingAim", Vector3.one * 0.12, RED)
	local aim = target.Root.Position
	local last = ctx.StartedAt
	local nextShot = ctx.StartedAt + config.Windup
	return function(now)
		local age = now - ctx.StartedAt
		if age >= config.Windup + config.Duration then return true end
		local tracked: Target? = nil
		for _, candidate in ctx.Targets() do
			if candidate.Player == target.Player then tracked = candidate; break end
		end
		if not tracked then return true end
		aim = aim:Lerp(tracked.Root.Position, 1 - math.exp(-config.Tracking * (now - last)))
		last = now
		local muzzle = ctx.Root.CFrame:PointToWorldSpace(Vector3.new(0, 3, -3.7))
		local offset = aim - muzzle
		local hit = Workspace:Raycast(muzzle, offset, Visual.RaycastParams(target.Player.Character))
		Beam(laser, muzzle, if hit then hit.Position else aim, 0.12)
		if now >= nextShot then
			nextShot = now + config.Interval
			Projectiles.Fire(muzzle, offset, config.Speed, config.Range, config.Damage, ctx.Damage, ctx.Model)
		end
		return false
	end
end

type Impact = { Position: Vector3, Marker: Part, Missile: Part?, At: number }
local function TimedAreas(ctx: Context, locations: { Vector3 }, windup: number, stagger: number, radius: number,
	damage: number, fallHeight: number?): Action
	local pending: { Impact } = {}
	for i, position in locations do
		local delayTime = windup + (i - 1) * stagger
		local marker = Visual.ShowArea(position, radius, delayTime + 1, RED)
		table.insert(ctx.Parts, marker)
		local missile: Part? = nil
		if fallHeight then
			missile = Part(ctx, "TitanMissile", Vector3.new(0.7, 2.8, 0.7), ORANGE)
			missile.Position = position + Vector3.new(0, fallHeight, 0)
		end
		table.insert(pending, { Position = position, Marker = marker, Missile = missile, At = ctx.StartedAt + delayTime })
	end
	return function(now)
		while pending[1] and now >= pending[1].At do
			local event = pending[1]
			table.remove(pending, 1)
			event.Marker:Destroy()
			if event.Missile then event.Missile:Destroy() end
			Visual.ShowArea(event.Position, radius, 0.25, ORANGE)
			Visual.DamageArea(event.Position, radius, damage, ctx.Damage)
		end
		if fallHeight then
			for _, event in pending do
				if event.Missile then
					local height = fallHeight * math.clamp((event.At - now) / windup, 0, 1)
					event.Missile.Position = event.Position + Vector3.new(0, height, 0)
				end
			end
		end
		return #pending == 0
	end
end

function Attacks.MissileRain(ctx: Context): Action
	local locations: { Vector3 } = {}
	local config = Config.Missile
	for _, target in ctx.Targets() do table.insert(locations, target.Root.Position) end
	if #locations == 1 then table.insert(locations, locations[1] + ctx.Frame.RightVector * config.SoloOffset) end
	return TimedAreas(ctx, locations, config.Windup, config.Stagger, config.Radius, config.Damage, config.FallHeight)
end

function Attacks.ArmSweep(ctx: Context): Action
	local config = Config.Sweep
	local halfArc = math.rad(config.ArcDegrees / 2)
	for i = 0, 8 do
		local angle = -halfArc + (2 * halfArc * i / 8)
		local frame = ctx.Frame * CFrame.Angles(0, angle, 0)
		local marker = Part(ctx, "TitanSweepWarning", Vector3.new(0.65, 0.12, config.Radius), RED)
		local ground = Workspace:Raycast(ctx.Frame.Position, Vector3.new(0, -32, 0), Visual.RaycastParams(nil))
		local y = if ground then ground.Position.Y + 0.15 else ctx.Frame.Position.Y - 4
		marker.CFrame = frame * CFrame.new(0, y - frame.Position.Y, -config.Radius / 2)
		marker.Transparency = 0.45
	end
	return function(now)
		if now < ctx.StartedAt + config.Windup then return false end
		HitOnce(ctx, {}, config.Damage, function(p)
			local range = Vector2.new(p.X, p.Z).Magnitude
			return math.abs(p.Y) <= 10 and range <= config.Radius and -p.Z >= range * math.cos(halfArc)
		end)
		return true
	end
end

function Attacks.RotatingLaser(ctx: Context, arcOverride: number?): Action
	local config = Config.Rotation
	local beam = Part(ctx, "TitanRotatingLaser", Vector3.one, RED)
	local arc = math.rad(arcOverride or config.ArcDegrees)
	local nextHit: { [Player]: number } = {}
	local previousYaw = 0
	return function(now)
		local time = now - ctx.StartedAt - config.Windup
		local yaw = arc * math.clamp(time / config.Duration, 0, 1)
		local frame = ctx.Frame * CFrame.Angles(0, yaw, 0)
		local from = frame.Position - Vector3.new(0, 2, 0)
		local ray = Workspace:Raycast(from, frame.LookVector * config.Range, Visual.RaycastParams(nil))
		local to = if ray then ray.Position else from + frame.LookVector * config.Range
		beam.Color = if time >= 0 then ORANGE else RED
		Beam(beam, from, to, if time >= 0 then config.Width else 0.18)
		if time < 0 then return false end
		for _, target in ctx.Targets() do
			local offset = ctx.Frame:PointToObjectSpace(target.Root.Position)
			local heading = math.atan2(-offset.X, -offset.Z)
			-- Use the full angle traversed since the previous AI tick, including at long range.
			local middle = (previousYaw + yaw) / 2
			heading = middle + (heading - middle + math.pi) % (2 * math.pi) - math.pi
			local nearestYaw = math.clamp(heading, previousYaw, yaw)
			local distance = Vector2.new(offset.X, offset.Z).Magnitude
			local deviation = heading - nearestYaw
			if now >= (nextHit[target.Player] or 0) and math.abs(deviation) < math.pi / 2
				and distance * math.cos(deviation) <= config.Range and math.abs(distance * math.sin(deviation)) <= config.Width / 2
				and math.abs(offset.Y + 2) <= 4
				and ClearShot(from, target) and ctx.Damage(target.Player, config.Damage) then
				nextHit[target.Player] = now + config.HitInterval
			end
		end
		previousYaw = yaw
		if time >= config.Duration then beam:Destroy(); return true end
		return false
	end
end

function Attacks.DroneSummon(ctx: Context): Action
	local config = Config.Drones
	local ring = Visual.ShowArea(ctx.Frame.Position, config.Radius, config.Windup + 1, SAFE)
	table.insert(ctx.Parts, ring)
	return function(now)
		if now < ctx.StartedAt + config.Windup then return false end
		ctx.Summon(ctx.Frame.Position)
		return true
	end
end

function Attacks.EnergyWall(ctx: Context): Action
	local config = Config.Wall
	local width = config.HalfLength - config.Gap / 2
	local left = GroundBox(ctx, "TitanWallWarning", -(width + config.Gap) / 2, -config.ForwardOffset, width, config.Width, RED)
	local right = GroundBox(ctx, "TitanWallWarning", (width + config.Gap) / 2, -config.ForwardOffset, width, config.Width, RED)
	local hit: { [Player]: boolean } = {}
	local raised = false
	return function(now)
		local age = now - ctx.StartedAt
		if age < config.Windup then return false end
		if age >= config.Windup + config.Duration then return true end
		if not raised then
			for _, wall in { left, right } do
				wall.Color = ORANGE
				wall.Size += Vector3.new(0, 5, 0)
				wall.Position += Vector3.new(0, 2.5, 0)
			end
			raised = true
		end
		HitOnce(ctx, hit, config.Damage, function(p)
			return math.abs(p.Y) <= 8 and math.abs(p.Z + config.ForwardOffset) <= config.Width / 2
				and math.abs(p.X) >= config.Gap / 2 and math.abs(p.X) <= config.HalfLength
		end)
		return false
	end
end

function Attacks.Overload(ctx: Context): Action
	SafeLane(ctx)
	local config = Config.Overload
	local locations: { Vector3 } = {}
	for _, offset in { Vector3.new(-7, -2, -config.ForwardOffset), Vector3.new(-12, -2, 0), Vector3.new(-7, -2, config.ForwardOffset) } do
		table.insert(locations, ctx.Frame:PointToWorldSpace(offset))
	end
	return TimedAreas(ctx, locations, config.Windup, config.Stagger, config.Radius, config.Damage)
end

function Attacks.HighSpeedCharge(ctx: Context): Action
	SafeLane(ctx)
	local config = Config.Charge
	local warning = GroundBox(ctx, "TitanChargeWarning", 0, -config.Range / 2, config.HalfWidth * 2, config.Range, RED)
	local distance = 0
	local hit: { [Player]: boolean } = {}
	local params = Visual.RaycastParams(nil)
	return function(now)
		if now < ctx.StartedAt + config.Windup then return false end
		warning.Color = ORANGE
		local requested = math.min((now - ctx.StartedAt - config.Windup) * config.Speed, config.Range)
		local travel = requested - distance
		if travel <= 0 then return false end
		local exclude = params.FilterDescendantsInstances
		for _, target in ctx.Targets() do
			local character = target.Player.Character
			if character and not table.find(exclude, character) then table.insert(exclude, character) end
		end
		params.FilterDescendantsInstances = exclude
		local obstruction = Workspace:Blockcast(ctx.Frame + ctx.Frame.LookVector * distance, Vector3.new(config.HalfWidth * 2, 4, 3),
			ctx.Frame.LookVector * travel, params)
		local stop = if obstruction then distance + math.max(0, obstruction.Distance - 0.1) else requested
		local pivot = ctx.Model:GetPivot()
		ctx.Model:PivotTo(pivot + ctx.Frame.LookVector * (stop - distance))
		HitOnce(ctx, hit, config.Damage, function(p)
			return math.abs(p.X) <= config.HalfWidth and math.abs(p.Y) <= 9 and -p.Z >= distance - 1 and -p.Z <= stop + 1
		end)
		distance = stop
		return obstruction ~= nil or distance >= config.Range
	end
end

function Attacks.CombinedAttack(ctx: Context): Action
	SafeLane(ctx)
	-- All hazards stay on the non-positive local X side. The marked right lane stays open.
	local laser = Attacks.RotatingLaser(ctx, Config.Combined.LaserArcDegrees)
	local locations: { Vector3 } = {}
	for _, z in { -18, -8, 6 } do
		table.insert(locations, ctx.Frame:PointToWorldSpace(Vector3.new(-Config.Combined.MissileOffset, -2, z)))
	end
	local config = Config.Missile
	local impact = TimedAreas(ctx, locations, config.Windup, config.Stagger, config.Radius, config.Damage, config.FallHeight)
	local laserDone, impactDone = false, false
	return function(now)
		if not laserDone then laserDone = laser(now) end
		if not impactDone then impactDone = impact(now) end
		return laserDone and impactDone
	end
end

return Attacks
