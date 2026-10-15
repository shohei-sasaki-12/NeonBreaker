--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local EnemyConfig = require(ConfigFolder:WaitForChild("EnemyConfig"))
local AIConfig = require(ConfigFolder:WaitForChild("EnemyAIConfig"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local MeleeAI = require(script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("EnemyAI"):WaitForChild("MeleeAI"))

type EnemyRecord = {
	AI: MeleeAI.Controller,
	Humanoid: Humanoid,
	Active: boolean,
	Connections: { RBXScriptConnection },
}

local aiFactories: { [string]: (Model, EnemyConfig.EnemyDefinition, (Player, number) -> boolean) -> MeleeAI.Controller } = {
	Melee = MeleeAI.new,
}
local records: { [Model]: EnemyRecord } = {}
local container: Folder? = nil
local templates: Folder? = nil
local heartbeat: RBXScriptConnection? = nil
local started = false
local nextUpdateAt = 0
local EnemyService = {}

local function StopAI(record: EnemyRecord)
	if record.Active then
		record.Active = false
		record.AI.Destroy()
	end
end

local function StopTracking(model: Model)
	local record = records[model]
	if not record then
		return
	end
	records[model] = nil
	StopAI(record)
	for _, connection in record.Connections do
		connection:Disconnect()
	end
end

function EnemyService.SpawnEnemy(enemyId: string, spawnCFrame: CFrame): Model?
	assert(started, "Call EnemyService.Init before spawning enemies")
	local destination = container
	local source = templates
	local config = EnemyConfig.GetEnemyConfig(enemyId)
	if not destination or not source or not config then
		return nil
	end
	local factory = aiFactories[config.AIType]
	local template = source:FindFirstChild(enemyId)
	if not factory or not template or not template:IsA("Model") then
		warn("[EnemyService] Missing model or AI for " .. enemyId)
		return nil
	end
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		warn("[EnemyService] Invalid enemy rig: " .. enemyId)
		return nil
	end
	model.PrimaryPart = root
	model:SetAttribute("EnemyId", config.EnemyId)
	humanoid.MaxHealth = config.MaxHP
	humanoid.Health = config.MaxHP
	humanoid.WalkSpeed = config.MoveSpeed
	model:PivotTo(spawnCFrame)
	model.Parent = destination
	-- Keep NPC physics on the server, along with targeting and damage.
	local canSetOwnership, reason = root:CanSetNetworkOwnership()
	if not canSetOwnership then
		model:Destroy()
		warn("[EnemyService] Cannot own enemy physics: " .. tostring(reason))
		return nil
	end
	root:SetNetworkOwner(nil)
	CollectionService:AddTag(model, "Enemy")
	local ai = factory(model, config, CombatService.ApplyEnemyDamage)
	local record: EnemyRecord = { AI = ai, Humanoid = humanoid, Active = true, Connections = {} }
	records[model] = record
	table.insert(record.Connections, humanoid.Died:Connect(function()
		-- Stop AI only; kill rewards and corpse removal belong to the next step.
		StopAI(record)
	end))
	table.insert(record.Connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(destination) then
			StopTracking(model)
		end
	end))
	return model
end

function EnemyService.DespawnEnemy(model: Model)
	if not records[model] then
		return
	end
	StopTracking(model)
	model:Destroy()
end

function EnemyService.Init()
	if started then
		return
	end
	assert(RunService:IsServer(), "EnemyService must run on the server")
	local destination = Workspace:WaitForChild("EnemyContainer")
	local source = ServerStorage:WaitForChild("EnemyModels")
	assert(destination:IsA("Folder") and source:IsA("Folder"), "Enemy containers must be Folders")
	if started then
		return
	end
	container = destination
	templates = source
	started = true
	nextUpdateAt = 0
	heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextUpdateAt then
			return
		end
		nextUpdateAt = now + AIConfig.UpdateInterval
		for model, record in records do
			if not model:IsDescendantOf(destination) then
				StopTracking(model)
			elseif record.Humanoid.Health <= 0 then
				StopAI(record)
			elseif record.Active then
				record.AI.Update(now)
			end
		end
	end)
end

function EnemyService.Destroy()
	if not started then
		return
	end
	started = false
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for model in records do
		EnemyService.DespawnEnemy(model)
	end
	container = nil
	templates = nil
end

return EnemyService
