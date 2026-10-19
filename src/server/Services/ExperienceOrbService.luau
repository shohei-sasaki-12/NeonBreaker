--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ExperienceOrbConfig"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

type Target = { Player: Player, Character: Model, Root: BasePart }
type Orb = { Experience: number, Target: Target?, Claimed: boolean }

local orbs: { [Part]: Orb } = {}
local container: Folder? = nil
local heartbeat: RBXScriptConnection? = nil
local started = false
local elapsed = 0
local ExperienceOrbService = {}

local function GetLivingTargets(): { Target }
	local targets: { Target } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if player.Parent == Players and character and character.Parent and humanoid and humanoid.Health > 0
			and root and root:IsA("BasePart") then
			table.insert(targets, { Player = player, Character = character, Root = root })
		end
	end
	return targets
end

local function SelectTarget(part: Part, orb: Orb, targets: { Target }): Target?
	-- Once attracted, keep following the same living character, even if it moves away.
	local current = orb.Target
	if current then
		for _, target in targets do
			if target.Player == current.Player and target.Character == current.Character then
				return target
			end
		end
	end
	local nearest: Target? = nil
	local nearestDistance = Config.AttractionRadius
	for _, target in targets do
		local distance = (target.Root.Position - part.Position).Magnitude
		if distance <= nearestDistance then
			nearestDistance = distance
			nearest = target
		end
	end
	return nearest
end

local function Collect(part: Part, orb: Orb, target: Target)
	if orb.Claimed or orbs[part] ~= orb then
		return
	end
	local character = target.Player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if target.Player.Parent ~= Players or character ~= target.Character or not humanoid or humanoid.Health <= 0
		or target.Root.Parent ~= character or (target.Root.Position - part.Position).Magnitude > Config.PickupRadius then
		orb.Target = nil
		return
	end
	-- Claim/remove before XP notifications can re-enter the update loop.
	orb.Claimed = true
	orbs[part] = nil
	if ProgressionService.AddExperience(target.Player, orb.Experience) then
		part:Destroy()
	elseif started and container and part:IsDescendantOf(container) then
		-- A player who left cannot consume an orb without receiving its XP.
		orb.Claimed = false
		orb.Target = nil
		orbs[part] = orb
	end
end

local function Update(deltaTime: number)
	elapsed += deltaTime
	if elapsed < Config.UpdateInterval then
		return
	end
	local movementDelta = math.min(elapsed, Config.MaxMovementDelta)
	elapsed = 0
	local targets = GetLivingTargets()
	local destination = container
	for part, orb in orbs do
		if not destination or not part:IsDescendantOf(destination) then
			orbs[part] = nil
			continue
		end
		local target = SelectTarget(part, orb, targets)
		orb.Target = target
		if not target then
			continue
		end
		local offset = target.Root.Position - part.Position
		local distance = offset.Magnitude
		if distance > Config.PickupRadius then
			local travel = math.min(distance, Config.MoveSpeed * movementDelta)
			part.Position += offset.Unit * travel
			distance = (target.Root.Position - part.Position).Magnitude
		end
		if distance <= Config.PickupRadius then
			Collect(part, orb, target)
		end
	end
end

function ExperienceOrbService.SpawnOrb(position: Vector3, experience: number): Part?
	assert(started, "Call ExperienceOrbService.Init before spawning orbs")
	local destination = container
	if not destination or experience ~= experience or experience <= 0 or experience == math.huge or experience % 1 ~= 0 then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "ExperienceOrb"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * Config.Diameter
	part.Color = Config.Color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false -- Radius collection avoids duplicate Touched callbacks.
	part.CanQuery = false -- Orbs do not obstruct bullets or enemy line-of-sight rays.
	part.CastShadow = false
	part.Position = position
	part:SetAttribute("ExperienceValue", experience)
	orbs[part] = { Experience = experience, Target = nil, Claimed = false }
	part.Parent = destination
	return part
end

function ExperienceOrbService.Init()
	if started then
		return
	end
	assert(RunService:IsServer(), "ExperienceOrbService must run on the server")
	local destination = Workspace:WaitForChild("ExperienceOrbs")
	assert(destination:IsA("Folder"), "ExperienceOrbs must be a Folder")
	if started then
		return
	end
	container = destination
	started = true
	elapsed = 0
	heartbeat = RunService.Heartbeat:Connect(Update)
end

function ExperienceOrbService.Destroy()
	if not started then
		return
	end
	started = false
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for part in orbs do
		orbs[part] = nil
		part:Destroy()
	end
	container = nil
end

return ExperienceOrbService
