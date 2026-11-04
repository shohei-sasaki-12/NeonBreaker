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
local EnemyStatus = require(script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("EnemyAI"):WaitForChild("EnemyStatus"))
local EMPConfig = require(ConfigFolder:WaitForChild("EMPConfig"))
local StatusEffects = require(script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("StatusEffects"))
local StatusEffectTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"):WaitForChild("StatusEffect"))

type EnemyRecord = {
	AI: MeleeAI.Controller,
	Status: EnemyStatus.Controller,
	Effects: StatusEffects.Controller,
	EMPShieldHandler: ((number) -> ())?,
	Humanoid: Humanoid,
	Active: boolean,
	EnemyId: string,
	Health: number,
	Dead: boolean,
	ExperienceReward: number,
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
type OrbSpawner = (position: Vector3, experience: number) -> Part?
local spawnExperienceOrb: OrbSpawner? = nil

local function StopAI(record: EnemyRecord)
	if record.Active then
		record.Active = false
		record.Effects.Destroy()
		record.Status.Destroy()
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

local function FinishDeath(model: Model, record: EnemyRecord, attacker: Player?): boolean
	if record.Dead or records[model] ~= record then
		return false
	end
	-- Commit death before Health/Died/ancestry callbacks can re-enter this path.
	record.Dead = true
	record.Health = 0
	local deathPosition = model:GetPivot().Position
	StopTracking(model)
	record.Humanoid.Health = 0
	local credit = if attacker then " by " .. attacker.Name else ""
	print("[EnemyService] Defeated " .. record.EnemyId .. credit)
	model:Destroy()
	local spawnOrb = spawnExperienceOrb
	if spawnOrb and record.ExperienceReward > 0 then
		spawnOrb(deathPosition, record.ExperienceReward)
	end
	return true
end

function EnemyService.ApplyDamage(model: Model, amount: number, attacker: Player?): boolean
	assert(RunService:IsServer(), "Enemy damage must run on the server")
	local record = records[model]
	local destination = container
	if not started or not record or record.Dead or not destination
		or not model:IsDescendantOf(destination) or not CollectionService:HasTag(model, "Enemy")
		or amount ~= amount or amount <= 0 or amount == math.huge then
		return false
	end
	-- Only this service writes gameplay HP; Humanoid.Health mirrors the server value.
	if record.Humanoid.Health <= 0 or record.Health <= 0 then
		FinishDeath(model, record, nil)
		return false
	end
	record.Health = math.max(0, record.Health - amount)
	if record.Health <= 0 then
		FinishDeath(model, record, attacker)
	else
		record.Humanoid.Health = record.Health
	end
	return true
end

local function GetLivingRecord(model: Model): EnemyRecord?
	local record = records[model]
	if not started or not record or record.Dead or not container or not model:IsDescendantOf(container)
		or not CollectionService:HasTag(model, "Enemy") or record.Health <= 0 or record.Humanoid.Health <= 0 then return nil end
	return record
end

-- Trusted server APIs only: no Remote exposes effect IDs, damage, stacks or duration.
function EnemyService.ApplyStatusEffect(model: Model, effect: StatusEffectTypes.Definition): boolean
	assert(RunService:IsServer(), "Enemy status effects must be applied on the server")
	local record = GetLivingRecord(model)
	if not record or not record.Effects.Apply(effect) or records[model] ~= record then return false end
	record.Status.Update(record.Effects.Update())
	return true
end

function EnemyService.RemoveStatusEffect(model: Model, effectId: string, sourcePlayer: Player?): boolean
	assert(RunService:IsServer(), "Enemy status effects must be removed on the server")
	local record = GetLivingRecord(model)
	if not record or not record.Effects.Remove(effectId, sourcePlayer) then return false end
	local slow = record.Effects.Update()
	if records[model] == record then record.Status.Update(slow) end
	return true
end

function EnemyService.GetStatusEffects(model: Model): { StatusEffectTypes.Snapshot }
	local record = GetLivingRecord(model)
	return if record then record.Effects.GetEffects() else table.freeze({})
end

-- Future enemy shield controllers register their server-owned durability damage API here.
-- No shield health is inferred from attributes or client data.
function EnemyService.RegisterEMPShieldHandler(model: Model, handler: (number) -> ()): boolean
	assert(RunService:IsServer(), "Enemy shield handlers must be registered on the server")
	local record = records[model]
	if not started or not record or record.Dead or typeof(handler) ~= "function" or record.EMPShieldHandler then return false end
	record.EMPShieldHandler = handler
	return true
end

function EnemyService.ApplyEMP(model: Model): boolean
	assert(RunService:IsServer(), "EMP must be applied on the server")
	local record = records[model]
	local destination = container
	if not started or not record or record.Dead or not destination or not model:IsDescendantOf(destination)
		or not CollectionService:HasTag(model, "Enemy") or record.Humanoid.Health <= 0 or record.Health <= 0 then return false end
	if not record.Status.ApplyEMP() then return false end
	local shieldHandler = record.EMPShieldHandler
	if shieldHandler then
		local amount = EMPConfig.ShieldDamage * (if record.EnemyId == "Guardian" then EMPConfig.GuardianShieldMultiplier else 1)
		local ok, message = pcall(shieldHandler, amount)
		if not ok then warn("[EnemyService] EMP shield handler failed: " .. tostring(message)) end
	end
	return true
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
	local record: EnemyRecord = {
		AI = ai, Humanoid = humanoid, Active = true, EnemyId = config.EnemyId,
		Status = EnemyStatus.new(model, humanoid, config), EMPShieldHandler = nil,
		Effects = StatusEffects.new(function(amount: number, sourcePlayer: Player?): boolean
			return EnemyService.ApplyDamage(model, amount, sourcePlayer)
		end),
		Health = config.MaxHP, Dead = false, ExperienceReward = config.ExperienceReward, Connections = {},
	}
	records[model] = record
	table.insert(record.Connections, humanoid.Died:Connect(function()
		FinishDeath(model, record, nil)
	end))
	table.insert(record.Connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(destination) then
			StopTracking(model)
		end
	end))
	return model
end

function EnemyService.GetEnemyCount(): number
	local destination = container
	if not started or not destination then return 0 end
	local count = 0
	for model, record in records do
		if not record.Dead and record.Health > 0 and record.Humanoid.Health > 0
			and model:IsDescendantOf(destination) then
			count += 1
		end
	end
	return count
end

-- Return each managed living enemy once, measured from its root on the server.
function EnemyService.GetEnemiesInRadius(position: Vector3, radius: number): { Model }
	local result: { Model } = {}
	local destination = container
	if not started or not destination then return result end
	for model, record in records do
		local root = model.PrimaryPart
		if not record.Dead and record.Health > 0 and record.Humanoid.Health > 0
			and model:IsDescendantOf(destination) and root and (root.Position - position).Magnitude <= radius then
			table.insert(result, model)
		end
	end
	return result
end

function EnemyService.DespawnEnemy(model: Model)
	if not records[model] then
		return
	end
	StopTracking(model)
	model:Destroy()
end

function EnemyService.Init(spawnOrb: OrbSpawner)
	if started then
		return
	end
	assert(RunService:IsServer(), "EnemyService must run on the server")
	assert(typeof(spawnOrb) == "function", "EnemyService requires an experience orb spawner")
	local destination = Workspace:WaitForChild("EnemyContainer")
	local source = ServerStorage:WaitForChild("EnemyModels")
	assert(destination:IsA("Folder") and source:IsA("Folder"), "Enemy containers must be Folders")
	if started then
		return
	end
	container = destination
	templates = source
	started = true
	spawnExperienceOrb = spawnOrb
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
				FinishDeath(model, record, nil)
			elseif record.Active then
				local slow = record.Effects.Update()
				-- A tick can kill/despawn this enemy and destroy its controllers.
				if records[model] == record and not record.Status.Update(slow) then record.AI.Update(now) end
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
	spawnExperienceOrb = nil
end

return EnemyService
