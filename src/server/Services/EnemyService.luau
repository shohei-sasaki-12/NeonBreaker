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
local AIFolder = script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("EnemyAI")
local RangedAI = require(AIFolder:WaitForChild("RangedAI"))
local ChargeAI = require(AIFolder:WaitForChild("ChargeAI"))
local SlamAI = require(AIFolder:WaitForChild("SlamAI"))
local SupportAI = require(AIFolder:WaitForChild("SupportAI"))
local EnemyArmor = require(AIFolder:WaitForChild("EnemyArmor"))
local EnemyAttacks = require(AIFolder:WaitForChild("EnemyAttacks"))
local EnemyProjectiles = require(AIFolder:WaitForChild("EnemyProjectiles"))
local EliteConfig = require(ConfigFolder:WaitForChild("EliteConfig"))
local EnemyStatus = require(script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("EnemyAI"):WaitForChild("EnemyStatus"))
local CryoStatus = require(script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("EnemyAI"):WaitForChild("CryoStatus"))
local EMPConfig = require(ConfigFolder:WaitForChild("EMPConfig"))
local FireConfig = require(ConfigFolder:WaitForChild("FireConfig"))
local BossResistance = require(ConfigFolder:WaitForChild("BossResistanceConfig"))
local StatusEffects = require(script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("StatusEffects"))
local StatusEffectTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"):WaitForChild("StatusEffect"))

type EnemyRecord = {
	AI: MeleeAI.Controller,
	Armor: EnemyArmor.Controller?,
	EliteAbility: string?,
	OnBossDefeated: ((Model, Vector3) -> ())?,
	Status: EnemyStatus.Controller,
	Effects: StatusEffects.Controller,
	Cryo: CryoStatus.Controller,
	EMPShieldHandler: ((number) -> ())?,
	Humanoid: Humanoid,
	Active: boolean,
	EnemyId: string,
	Config: EnemyConfig.EnemyDefinition,
	Health: number,
	Dead: boolean,
	ExperienceReward: number,
	Connections: { RBXScriptConnection },
}

local aiFactories: { [string]: (Model, EnemyConfig.EnemyDefinition, (Player, number) -> boolean) -> MeleeAI.Controller } = {
	Melee = MeleeAI.new,
	Ranged = RangedAI.new,
	Charge = ChargeAI.new,
	Slam = SlamAI.new,
}
local random = Random.new()
local records: { [Model]: EnemyRecord } = {}
local container: Folder? = nil
local templates: Folder? = nil
local heartbeat: RBXScriptConnection? = nil
local started = false
local nextUpdateAt = 0
local EnemyService = {}
type BossOptions = {
	CreateAI: (Model) -> MeleeAI.Controller,
	OnDefeated: (Model, Vector3) -> (),
}
type OrbSpawner = (position: Vector3, experience: number) -> Part?
local spawnExperienceOrb: OrbSpawner? = nil

local function StopAI(record: EnemyRecord)
	if record.Active then
		record.Active = false
		record.Effects.Destroy()
		record.Cryo.Destroy()
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
	if record.EliteAbility == "ExplosionOnDeath" then
		EnemyAttacks.ShowArea(deathPosition, EliteConfig.ExplosionRadius, EliteConfig.ExplosionLifetime, EliteConfig.OutlineColor)
		EnemyAttacks.DamageArea(deathPosition, EliteConfig.ExplosionRadius, EliteConfig.ExplosionDamage, CombatService.ApplyEnemyDamage)
	end
	local spawnOrb = spawnExperienceOrb
	if spawnOrb and record.ExperienceReward > 0 then
		spawnOrb(deathPosition, record.ExperienceReward)
	end
	if record.OnBossDefeated then record.OnBossDefeated(model, deathPosition) end
	return true
end

function EnemyService.ApplyDamage(model: Model, amount: number, attacker: Player?, origin: Vector3?): boolean
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
	local armor = record.Armor
	local remaining = if armor then armor.Absorb(amount, origin) else amount
	if remaining <= 0 then return true end
	record.Health = math.max(0, record.Health - remaining * (1 - (record.Config.DamageReduction or 0)))
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

function EnemyService.Heal(model: Model, amount: number): boolean
	assert(RunService:IsServer(), "Enemy healing must run on the server")
	local record = GetLivingRecord(model)
	if not record or not (amount > 0 and amount < math.huge) or record.Health >= record.Config.MaxHP then return false end
	record.Health = math.min(record.Config.MaxHP, record.Health + amount)
	record.Humanoid.Health = record.Health
	return true
end

-- Callers supply desired velocity change in studs/sec. Resist before converting to impulse.
function EnemyService.ApplyKnockback(model: Model, velocityDelta: Vector3): boolean
	assert(RunService:IsServer(), "Enemy knockback must run on the server")
	local record = GetLivingRecord(model)
	local root = model.PrimaryPart
	local magnitude = velocityDelta.Magnitude
	if not record or not root or not (magnitude > 0 and magnitude < math.huge) then return false end
	local resistance = record.Config.KnockbackResistance or 0
	root:ApplyImpulse(velocityDelta * (root.AssemblyMass * (1 - resistance)))
	return true
end

local function UpdateStatus(record: EnemyRecord): boolean
	local slow = record.Effects.Update()
	if record.Dead or not record.Active then return true end
	local cryo = record.Cryo.Update()
	return record.Status.Update(math.max(slow, cryo.SlowRate), cryo.IsFrozen)
end

function EnemyService.IsBoss(model: Model): boolean
	local record = GetLivingRecord(model)
	return record ~= nil and EnemyStatus.IsBoss(model, record.Config)
end

function EnemyService.ApplyCryo(model: Model, level: number): boolean
	assert(RunService:IsServer(), "Enemy cooling must be applied on the server")
	local record = GetLivingRecord(model)
	if not record or not record.Cryo.AddCooling(level) then return false end
	UpdateStatus(record)
	return true
end

function EnemyService.GetCryoState(model: Model): CryoStatus.Snapshot?
	local record = GetLivingRecord(model)
	return if record then record.Cryo.Update() else nil
end

-- Trusted server APIs only: no Remote exposes effect IDs, damage, stacks or duration.
function EnemyService.ApplyStatusEffect(model: Model, effect: StatusEffectTypes.Definition): boolean
	assert(RunService:IsServer(), "Enemy status effects must be applied on the server")
	local record = GetLivingRecord(model)
	if not record then return false end
	if typeof(effect) == "table" and effect.EffectId == FireConfig.EffectId
		and typeof(effect.TickDamage) == "number" and EnemyStatus.IsBoss(model, record.Config) then
		local adjusted = table.clone(effect)
		adjusted.TickDamage = effect.TickDamage * BossResistance.FireTickDamageMultiplier
		effect = adjusted
	end
	if not record.Effects.Apply(effect) or records[model] ~= record then return false end
	UpdateStatus(record)
	return true
end

function EnemyService.RemoveStatusEffect(model: Model, effectId: string, sourcePlayer: Player?): boolean
	assert(RunService:IsServer(), "Enemy status effects must be removed on the server")
	local record = GetLivingRecord(model)
	if not record or not record.Effects.Remove(effectId, sourcePlayer) then return false end
	UpdateStatus(record)
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

function EnemyService.SpawnEnemy(enemyId: string, spawnCFrame: CFrame, isElite: boolean?, bossOptions: BossOptions?): Model?
	assert(started, "Call EnemyService.Init before spawning enemies")
	local destination = container
	local source = templates
	local definition = EnemyConfig.GetEnemyConfig(enemyId)
	if not destination or not source or not definition then
		return nil
	end
	local config = definition
	local ability: string? = nil
	local scale = config.Scale or 1
	if isElite and not definition.IsBoss then
		local elite = table.clone(definition)
		elite.MaxHP *= EliteConfig.HealthMultiplier
		elite.Damage *= EliteConfig.DamageMultiplier
		elite.MoveSpeed *= EliteConfig.MoveSpeedMultiplier
		elite.ExperienceReward *= EliteConfig.ExperienceMultiplier
		config = elite
		scale *= EliteConfig.ScaleMultiplier
		ability = EliteConfig.Abilities[random:NextInteger(1, #EliteConfig.Abilities)]
	end
	local factory = aiFactories[config.AIType]
	local template = source:FindFirstChild(enemyId)
	if not template and config.FallbackTemplate then
		template = source:FindFirstChild(config.FallbackTemplate)
	end
	local canBuildAI = factory ~= nil or config.AIType == "Support" or (config.IsBoss == true and bossOptions ~= nil)
	if not canBuildAI or not template or not template:IsA("Model") then
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
	model.Name = enemyId
	model:SetAttribute("EnemyId", config.EnemyId)
	model:SetAttribute("IsElite", ability ~= nil)
	local color = config.Color
	if color then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= root then part.Color = color end
		end
	end
	if scale ~= 1 then model:ScaleTo(scale) end
	local densityMultiplier = config.RootDensityMultiplier
	if densityMultiplier then
		local physics = root.CurrentPhysicalProperties
		root.CustomPhysicalProperties = PhysicalProperties.new(
			physics.Density * densityMultiplier, physics.Friction, physics.Elasticity,
			physics.FrictionWeight, physics.ElasticityWeight
		)
	end
	if ability then
		model:SetAttribute("EliteAbility", ability)
		local highlight = Instance.new("Highlight")
		highlight.Name = "EliteOutline"
		highlight.OutlineColor = EliteConfig.OutlineColor
		highlight.FillTransparency = 0.85
		highlight.FillColor = EliteConfig.OutlineColor
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	end
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
	local ai: MeleeAI.Controller
	if config.IsBoss and bossOptions then
		CollectionService:AddTag(model, "Boss")
		ai = bossOptions.CreateAI(model)
	elseif factory then
		ai = factory(model, config, CombatService.ApplyEnemyDamage)
	else
		ai = SupportAI.new(model, config, EnemyService.GetEnemiesInRadius, EnemyService.Heal)
	end
	local armor = if config.Shield or ability == "EnergyShield"
		then EnemyArmor.new(model, root, config.Shield, ability == "EnergyShield") else nil
	local record: EnemyRecord = {
		AI = ai, Armor = armor, EliteAbility = ability,
		OnBossDefeated = if config.IsBoss and bossOptions then bossOptions.OnDefeated else nil,
		Humanoid = humanoid, Active = true, EnemyId = config.EnemyId, Config = config,
		Status = EnemyStatus.new(model, humanoid, config), EMPShieldHandler = nil,
		Cryo = CryoStatus.new(model, config),
		Effects = StatusEffects.new(function(amount: number, sourcePlayer: Player?): boolean
			return EnemyService.ApplyDamage(model, amount, sourcePlayer)
		end),
		Health = config.MaxHP, Dead = false, ExperienceReward = config.ExperienceReward, Connections = {},
	}
	records[model] = record
	if config.Shield and armor then EnemyService.RegisterEMPShieldHandler(model, armor.ApplyEMP) end
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
		EnemyProjectiles.Update(now)
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
				if record.Armor then record.Armor.Update() end
				local blocked = UpdateStatus(record)
				-- A tick can kill/despawn this enemy and destroy its controllers.
				if records[model] == record then
					if not blocked then
						record.AI.Update(now)
					elseif record.AI.Interrupt then
						record.AI.Interrupt()
					end
				end
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
	EnemyProjectiles.Clear()
	container = nil
	templates = nil
	spawnExperienceOrb = nil
end

return EnemyService
