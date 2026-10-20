--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SpawnConfig"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local StageService = require(script.Parent:WaitForChild("StageService"))

local SpawnService = {}
local started = false
local heartbeat: RBXScriptConnection? = nil
local spawnPoints: Folder? = nil
local wasRunning = false
local nextSpawnAt = 0
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

local function ChooseSpawn(positions: { Vector3 }): CFrame?
	local folder = spawnPoints
	if not folder then return nil end
	local candidates: { CFrame } = {}
	for _, point in folder:GetChildren() do
		if not point:IsA("BasePart") or point:GetAttribute("Enabled") == false
			or point:GetAttribute("BossOnly") == true then
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
		if safe then table.insert(candidates, location) end
	end
	return if #candidates > 0 then candidates[random:NextInteger(1, #candidates)] else nil
end

local function Update()
	local stage = StageService.GetState()
	if stage.State ~= "Running" or stage.RemainingSeconds <= 0 then
		wasRunning = false
		return
	end
	local now = os.clock()
	if not wasRunning then
		wasRunning = true
		nextSpawnAt = now + Config.SpawnInterval
		return
	end
	if now < nextSpawnAt then return end
	-- No catch-up burst after a slow frame, full capacity, or unsafe spawn points.
	nextSpawnAt = now + Config.SpawnInterval
	if EnemyService.GetEnemyCount() >= Config.MaxEnemies then return end
	local positions = GetPlayerPositions()
	if #positions == 0 then return end
	local location = ChooseSpawn(positions)
	if location then
		EnemyService.SpawnEnemy(Config.EnemyId, location)
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
	wasRunning = false
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
	wasRunning = false
	nextSpawnAt = 0
end

return SpawnService
