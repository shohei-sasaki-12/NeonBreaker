--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Config = require(Shared:WaitForChild("AegisWalkerConfig"))
local Titan = require(Shared:WaitForChild("CoreTitanConfig"))
local SpawnConfig = require(Shared:WaitForChild("SpawnConfig"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local StageService = require(script.Parent:WaitForChild("StageService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local Modules = script.Parent.Parent:WaitForChild("ServerModules")
local AI = require(Modules:WaitForChild("BossAI"):WaitForChild("AegisWalkerAI"))
local Attacks = require(Modules:WaitForChild("EnemyAI"):WaitForChild("EnemyAttacks"))

type HealingDrop = { Part: Part, ExpiresAt: number }
local AegisWalkerService = {}
local started = false
local boss: Model? = nil
local spawnAt: number? = nil
local healthConnection: RBXScriptConnection? = nil
local drop: HealingDrop? = nil
local nextPickupCheck = 0
local connections: { RBXScriptConnection } = {}

local function Ground(position: Vector3, living: { Player }): Vector3?
	local params = Attacks.RaycastParams(nil)
	local ignore = params.FilterDescendantsInstances
	for _, player in living do
		local character = player.Character
		if character then table.insert(ignore, character) end
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(position + Vector3.new(0, 24, 0), Vector3.new(0, -72, 0), params)
	return if result then result.Position else nil
end

local function FindSpawn(living: { Player }): CFrame?
	local points = Workspace:FindFirstChild("SpawnPoints")
	if points then
		for _, point in points:GetChildren() do
			if point:IsA("BasePart") and point:GetAttribute("BossOnly") == true
				and point:GetAttribute("Enabled") ~= false and point:GetAttribute("EnemyId") ~= Titan.Id then
				return point.CFrame + Vector3.new(0, Config.SpawnOffset, 0)
			end
		end
	end
	local ground = Ground(Config.FallbackPosition, living)
	return if ground then CFrame.new(ground + Vector3.new(0, Config.SpawnOffset, 0)) else nil
end

local function Summon(position: Vector3, living: { Player })
	if #living == 0 then return end
	local reinforcement = Config.Reinforcement
	local count = reinforcement.WaveSize[math.min(#living, #reinforcement.WaveSize)]
	local slots = math.min(count, SpawnConfig.MaxEnemies - EnemyService.GetEnemyCount())
	for i = 1, count do
		if slots <= 0 then break end
		local angle = (i - 1) * math.pi * 2 / count
		local site = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reinforcement.Radius
		local ground = Ground(site, living)
		if not ground then continue end
		local spawnPosition = ground + Vector3.new(0, SpawnConfig.SpawnHeightOffset, 0)
		local nearPlayer = false
		for _, player in living do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") and (root.Position - spawnPosition).Magnitude < reinforcement.MinPlayerDistance then
				nearPlayer = true
				break
			end
		end
		if not nearPlayer and EnemyService.SpawnEnemy(if i % 2 == 1 then "Striker" else "ShooterDrone", CFrame.new(spawnPosition)) then
			slots -= 1
		end
	end
end

local function ClearHealthConnection()
	if healthConnection then healthConnection:Disconnect(); healthConnection = nil end
end

local function ClearDrop()
	if drop then drop.Part:Destroy(); drop = nil end
end

local function Cleanup()
	spawnAt = nil
	ClearHealthConnection()
	local active = boss
	boss = nil
	if active then EnemyService.DespawnEnemy(active) end
	ClearDrop()
end

local function OnDefeated(model: Model, position: Vector3)
	if boss ~= model then return end
	boss = nil -- Consume the active encounter before publishing or creating rewards.
	ClearHealthConnection()
	if not StageService.ReportMidBoss("Defeated") then return end
	local settings = Config.HealingDrop
	local effects = Workspace:FindFirstChild("EffectContainer") or Workspace
	local ground = Ground(position, StageService.GetLivingParticipants()) or position
	local part = Attacks.MakeVisual("AegisHealingDrop", Color3.fromRGB(92, 255, 140), Vector3.one * 2)
	part.Position = ground + Vector3.new(0, 1, 0)
	part:SetAttribute("HealAmount", settings.Amount)
	part.Parent = effects
	drop = { Part = part, ExpiresAt = Workspace:GetServerTimeNow() + settings.Lifetime }
	nextPickupCheck = 0
end

local function SpawnBoss()
	local living = StageService.GetLivingParticipants()
	local cframe = FindSpawn(living)
	if #living == 0 or not cframe or EnemyService.GetEnemyCount() >= SpawnConfig.MaxEnemies then
		StageService.ReportMidBoss("Unavailable")
		return
	end
	local model = EnemyService.SpawnEnemy(Config.Id, cframe, false, {
		CreateAI = function(rig)
			return AI.new(rig, {
				GetLiving = StageService.GetLivingParticipants,
				IsLiving = StageService.IsLivingParticipant,
				Damage = CombatService.ApplyEnemyDamage,
				Summon = Summon,
			})
		end,
		OnDefeated = OnDefeated,
	})
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if not model or not humanoid then
		if model then EnemyService.DespawnEnemy(model) end
		StageService.ReportMidBoss("Unavailable")
		return
	end
	boss = model
	healthConnection = humanoid.HealthChanged:Connect(function(health: number)
		if boss == model and health > 0 then StageService.ReportMidBoss("Active", health, humanoid.MaxHealth) end
	end)
	StageService.ReportMidBoss("Active", humanoid.Health, humanoid.MaxHealth)
end

local function Update()
	if StageService.GetState().State ~= "Running" then
		if boss or spawnAt or drop then Cleanup() end
		return
	end
	local now = Workspace:GetServerTimeNow()
	if spawnAt and now >= spawnAt then
		spawnAt = nil
		SpawnBoss()
	end
	if boss and not boss.Parent then
		boss = nil
		ClearHealthConnection()
		StageService.ReportMidBoss("Unavailable")
	end
	local pickup = drop
	if not pickup then return end
	if not pickup.Part.Parent or now >= pickup.ExpiresAt then ClearDrop(); return end
	if now < nextPickupCheck then return end
	nextPickupCheck = now + Config.HealingDrop.CheckInterval
	local nearestHumanoid: Humanoid? = nil
	local nearestDistance = Config.HealingDrop.Radius
	for _, player in StageService.GetLivingParticipants() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if root and root:IsA("BasePart") and humanoid and humanoid.Health < humanoid.MaxHealth then
			local distance = (root.Position - pickup.Part.Position).Magnitude
			if distance <= nearestDistance then nearestDistance, nearestHumanoid = distance, humanoid end
		end
	end
	if nearestHumanoid then
		ClearDrop()
		nearestHumanoid.Health = math.min(nearestHumanoid.MaxHealth, nearestHumanoid.Health + Config.HealingDrop.Amount)
	end
end

function AegisWalkerService.Init()
	if started then return end
	assert(RunService:IsServer(), "AegisWalkerService must run on the server")
	started = true
	table.insert(connections, StageService.MidBossRequested:Connect(function()
		if StageService.ReportMidBoss("Warning") then spawnAt = Workspace:GetServerTimeNow() + Config.IntroDuration end
	end))
	table.insert(connections, RunService.Heartbeat:Connect(Update))
end

function AegisWalkerService.Destroy()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	Cleanup()
	started = false
end

return AegisWalkerService
