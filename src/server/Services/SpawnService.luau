--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SpawnConfig"))
local SharedConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local StageConfig = require(SharedConfig:WaitForChild("StageConfig"))
local EliteConfig = require(SharedConfig:WaitForChild("EliteConfig"))
local EnemyConfig = require(SharedConfig:WaitForChild("EnemyConfig"))
local AegisConfig = require(SharedConfig:WaitForChild("AegisWalkerConfig"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local StageService = require(script.Parent:WaitForChild("StageService"))

local SpawnService = {}
local started = false
local heartbeat: RBXScriptConnection? = nil
local spawnPoints: Folder? = nil
local currentPhase: StageConfig.PhaseId? = nil
local nextSpawnAt = 0
local nextRefillAt = 0
local budget = 0
local random = Random.new()

local function GetPlayerPositions(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if character and character.Parent and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

local function GetSafeSpawns(positions: { Vector3 }): { BasePart }
	local candidates: { BasePart } = {}
	local folder = spawnPoints
	if not folder then return candidates end
	for _, point in folder:GetChildren() do
		if not point:IsA("BasePart") or point:GetAttribute("Enabled") == false
			or point:GetAttribute("BossOnly") == true
			or (point:GetAttribute("DropPod") == true and point:GetAttribute("DropPodActive") ~= true) then
			continue
		end
		local location = point.CFrame + Vector3.new(0, Config.SpawnHeightOffset, 0)
		local safe = true
		for _, position in positions do
			if (location.Position - position).Magnitude < Config.MinPlayerDistance then
				safe = false
				break
			end
		end
		if safe then table.insert(candidates, point) end
	end
	return candidates
end

local function ChooseEnemy(phase: StageConfig.Phase, point: BasePart, used: { [string]: boolean }): (string?, boolean, number)
	local requested = point:GetAttribute("EnemyId")
	local pool = phase.EnemyPool
	if typeof(requested) == "string" and table.find(pool, requested) then
		pool = { requested }
	end
	local forcedElite = point:GetAttribute("IsElite")
	local elite = phase.EliteChance > 0 and (forcedElite == true
		or (forcedElite ~= false and random:NextNumber() < phase.EliteChance))
	local newTypes: { string } = {}
	local affordable: { string } = {}
	local costs: { [string]: number } = {}
	for _, enemyId in pool do
		local enemy = EnemyConfig.GetEnemyConfig(enemyId)
		if enemy then
			local cost = enemy.ThreatCost * (if elite then EliteConfig.ThreatCostMultiplier else 1)
			if cost <= budget then
				costs[enemyId] = cost
				table.insert(affordable, enemyId)
				if not used[enemyId] then table.insert(newTypes, enemyId) end
			end
		end
	end
	local choices = if #newTypes > 0 then newTypes else affordable
	if #choices == 0 then return nil, elite, 0 end
	local enemyId = choices[random:NextInteger(1, #choices)]
	return enemyId, elite, costs[enemyId]
end

local function Update()
	local stage = StageService.GetState()
	if stage.State ~= "Running" or stage.RemainingSeconds <= 0 then
		currentPhase = nil
		return
	end
	local now = os.clock()
	local phase = StageConfig.GetPhase(stage.ElapsedSeconds)
	if currentPhase ~= phase.Id then
		currentPhase = phase.Id
		budget = phase.ThreatBudget
		nextRefillAt = now + Config.BudgetRefillInterval
		nextSpawnAt = now + phase.SpawnInterval
		return
	end
	if now >= nextRefillAt then
		budget = phase.ThreatBudget
		nextRefillAt = now + Config.BudgetRefillInterval
	end
	if now < nextSpawnAt then return end
	-- No catch-up burst after a slow frame, full capacity, or unsafe spawn points.
	nextSpawnAt = now + phase.SpawnInterval
	local reservingBoss = stage.MidBossState == "Pending" or stage.MidBossState == "Warning"
	local bossEncounter = stage.MidBossState == "Warning" or stage.MidBossState == "Active"
	local waveSize = if bossEncounter then math.max(1, math.floor(phase.WaveSize * AegisConfig.EncounterSpawnMultiplier)) else phase.WaveSize
	local cap = Config.MaxEnemies - (if reservingBoss then 1 else 0)
	local slots = math.min(waveSize, cap - EnemyService.GetEnemyCount())
	if slots <= 0 or budget <= 0 then return end
	local positions = GetPlayerPositions()
	if #positions == 0 then return end
	local safe = GetSafeSpawns(positions)
	if #safe == 0 then return end
	local available = table.clone(safe)
	local used: { [string]: boolean } = {}
	for _ = 1, slots do
		if budget <= 0 then break end
		if #available == 0 then available = table.clone(safe) end
		local point = table.remove(available, random:NextInteger(1, #available))
		if not point then break end
		local enemyId, elite, cost = ChooseEnemy(phase, point, used)
		if enemyId then
			local location = point.CFrame + Vector3.new(0, Config.SpawnHeightOffset, 0)
			if EnemyService.SpawnEnemy(enemyId, location, elite) then
				budget -= cost
				used[enemyId] = true
			end
		end
	end
end

function SpawnService.Init()
	if started then return end
	assert(RunService:IsServer(), "SpawnService must run on the server")
	local folder = Workspace:WaitForChild("SpawnPoints")
	assert(folder:IsA("Folder"), "SpawnPoints must be a Folder")
	if started then return end
	spawnPoints = folder
	started = true
	currentPhase = nil
	if not folder:FindFirstChildWhichIsA("BasePart") then
		warn("[SpawnService] Add BasePart markers under Workspace/SpawnPoints to enable spawning")
	end
	heartbeat = RunService.Heartbeat:Connect(Update)
end

function SpawnService.Destroy()
	if not started then return end
	started = false
	if heartbeat then heartbeat:Disconnect() end
	heartbeat = nil
	spawnPoints = nil
	currentPhase = nil
	nextSpawnAt = 0
	nextRefillAt = 0
	budget = 0
end

return SpawnService
