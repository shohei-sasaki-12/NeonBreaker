--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Config = require(Shared:WaitForChild("CoreTitanConfig"))
local SpawnConfig = require(Shared:WaitForChild("SpawnConfig"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local StageService = require(script.Parent:WaitForChild("StageService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local Modules = script.Parent.Parent:WaitForChild("ServerModules")
local BossAI = Modules:WaitForChild("BossAI")
local AI = require(BossAI:WaitForChild("CoreTitanAI"))
local Attacks = require(BossAI:WaitForChild("CoreTitanAttacks"))
local Visual = require(Modules:WaitForChild("EnemyAI"):WaitForChild("EnemyAttacks"))

local CoreTitanService = {}
local boss: Model? = nil
local spawnAt: number? = nil
local healthConnection: RBXScriptConnection? = nil
local connections: { RBXScriptConnection } = {}

local function Targets(): { Attacks.Target }
	local targets: { Attacks.Target } = {}
	for _, player in StageService.GetLivingParticipants() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then table.insert(targets, { Player = player, Root = root }) end
	end
	return targets
end

local function Ground(position: Vector3, targets: { Attacks.Target }): Vector3?
	local params = Visual.RaycastParams(nil)
	local ignore = params.FilterDescendantsInstances
	for _, target in targets do
		local character = target.Player.Character
		if character then table.insert(ignore, character) end
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 24, 0), Vector3.new(0, -72, 0), params)
	return if hit then hit.Position else nil
end

local function FindSpawn(targets: { Attacks.Target }): CFrame?
	local points = Workspace:FindFirstChild("SpawnPoints")
	if points then
		for _, point in points:GetChildren() do
			if point:IsA("BasePart") and point:GetAttribute("BossOnly") == true
				and point:GetAttribute("EnemyId") == Config.Id and point:GetAttribute("Enabled") ~= false then
				return point.CFrame + Vector3.new(0, Config.SpawnHeight, 0)
			end
		end
	end
	local ground = Ground(Config.SpawnPosition, targets)
	return if ground then CFrame.new(ground + Vector3.new(0, Config.SpawnHeight, 0)) else nil
end

local function Summon(position: Vector3)
	local config = Config.Drones
	local targets = Targets()
	local slots = SpawnConfig.MaxEnemies - EnemyService.GetEnemyCount()
	for i = 1, config.Count do
		if slots <= 0 then break end
		local angle = (i - 1) * math.pi * 2 / config.Count
		local ground = Ground(position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * config.Radius, targets)
		if not ground then continue end
		local site = ground + Vector3.new(0, SpawnConfig.SpawnHeightOffset, 0)
		local near = false
		for _, target in targets do
			if (site - target.Root.Position).Magnitude < config.MinPlayerDistance then near = true; break end
		end
		if not near and EnemyService.SpawnEnemy("ShooterDrone", CFrame.new(site)) then slots -= 1 end
	end
end

local function Cleanup()
	boss, spawnAt = nil, nil
	if healthConnection then healthConnection:Disconnect(); healthConnection = nil end
	EnemyService.ClearEncounter()
end

local function OnDefeated(model: Model)
	if boss ~= model then return end
	Cleanup()
	StageService.FinishFinalBoss(true)
end

local function SpawnBoss()
	local targets = Targets()
	local frame = if #targets > 0 then FindSpawn(targets) else nil
	if not frame then
		warn("[CoreTitanService] No valid spawn for CORE TITAN")
		StageService.FinishFinalBoss(false)
		return
	end
	local function Publish()
		local current = boss
		local humanoid = if current then current:FindFirstChildOfClass("Humanoid") else nil
		if current and humanoid and humanoid.Health > 0 then
			local phase = current:GetAttribute("BossPhase")
			StageService.ReportFinalBoss(humanoid.Health, humanoid.MaxHealth, if typeof(phase) == "number" then phase else 1,
				current:GetAttribute("CoreExposed") == true)
		end
	end
	local model = EnemyService.SpawnEnemy(Config.Id, frame, false, {
		CreateAI = function(rig)
			return AI.new(rig, {
				Targets = Targets,
				Damage = function(player, amount)
					return StageService.IsLivingParticipant(player) and CombatService.ApplyEnemyDamage(player, amount)
				end,
				Summon = Summon,
				Notify = Publish,
			})
		end,
		OnDefeated = OnDefeated,
	})
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if not model or not humanoid then
		if model then EnemyService.DespawnEnemy(model) end
		warn("[CoreTitanService] Failed to create CORE TITAN")
		StageService.FinishFinalBoss(false)
		return
	end
	boss = model
	healthConnection = humanoid.HealthChanged:Connect(Publish)
	Publish()
end

local function Update()
	if StageService.GetState().State ~= "Running" then
		if boss or spawnAt then Cleanup() end
		return
	end
	if spawnAt and Workspace:GetServerTimeNow() >= spawnAt then
		spawnAt = nil
		SpawnBoss()
	end
	if boss and not boss.Parent then
		Cleanup()
		StageService.FinishFinalBoss(false)
	end
end

function CoreTitanService.Init()
	if #connections > 0 then return end
	assert(RunService:IsServer(), "CoreTitanService must run on the server")
	table.insert(connections, StageService.FinalBossRequested:Connect(function()
		if StageService.GetState().FinalBossState ~= "Warning" or spawnAt or boss then return end
		EnemyService.ClearEncounter()
		spawnAt = Workspace:GetServerTimeNow() + Config.IntroDuration
	end))
	table.insert(connections, RunService.Heartbeat:Connect(Update))
end

function CoreTitanService.Destroy()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	if boss or spawnAt then Cleanup() end
end

return CoreTitanService
