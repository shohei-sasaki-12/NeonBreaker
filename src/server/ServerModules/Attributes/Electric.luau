--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ElectricConfig"))
local BossResistance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BossResistanceConfig"))
local PlayerStateService = require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))
local Validation = require(script.Parent.Parent:WaitForChild("CombatValidation"))

type EnemyQuery = (Vector3, number) -> { Model }
type DamageHandler = (Model, number, Player?, Vector3?) -> boolean
local queryEnemies: EnemyQuery? = nil
local applyDamage: DamageHandler? = nil
local effectsRemote: RemoteEvent? = nil
local random = Random.new()
local Electric = {}

local function Params(player: Player): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local excluded: { Instance } = {}
	if player.Character then table.insert(excluded, player.Character) end
	for _, name in { "EnemyContainer", "ProjectileContainer", "SpawnPoints" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then table.insert(excluded, folder) end
	end
	params.FilterDescendantsInstances = excluded
	return params
end

-- Only validated weapon hits enter here. Chain damage calls EnemyService directly.
function Electric.OnHit(player: Player, firstEnemy: Model, originalDamage: number, position: Vector3, isBoss: boolean?): boolean
	assert(RunService:IsServer(), "Electric must be processed on the server")
	local query, damage = queryEnemies, applyDamage
	local state = PlayerStateService.GetState(player)
	if not query or not damage or player.Parent ~= Players or not state
		or not Validation.IsFinite(originalDamage) or originalDamage <= 0 or not Validation.IsVector(position) then return false end
	local count = Config.GetChainCount(state.Upgrades.Electric or 0)
	if count == 0 or random:NextNumber() >= Config.Chance then return false end
	if isBoss then
		return damage(firstEnemy, originalDamage * BossResistance.ElectricBonusDamageMultiplier, player)
	end
	local visited: { [Model]: boolean } = { [firstEnemy] = true }
	local currentPosition = position -- Captured before direct damage can delete the first enemy.
	local chainDamage = originalDamage * Config.DamageMultiplier
	local params = Params(player)
	local hitAny = false
	for _ = 1, count do
		local target: Model? = nil
		local targetPosition: Vector3? = nil
		local nearest = math.huge
		for _, enemy in query(currentPosition, Config.ChainRange) do
			local root = enemy.PrimaryPart
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			if visited[enemy] or not root or not humanoid or humanoid.Health <= 0 then continue end
			local offset = root.Position - currentPosition
			local distance = offset.Magnitude
			if distance > Config.ChainRange or distance >= nearest then continue end
			if distance > 0 and Workspace:Raycast(currentPosition, offset, params) then continue end
			target, targetPosition, nearest = enemy, root.Position, distance
		end
		if not target or not targetPosition then break end
		visited[target] = true -- Commit before damage/death callbacks; never revisit a model.
		if not damage(target, chainDamage, player, currentPosition) then break end
		hitAny = true
		if effectsRemote then
			effectsRemote:FireAllClients({ SpecialId = "Electric", Event = "Chained", Origin = currentPosition, Position = targetPosition })
		end
		currentPosition = targetPosition -- Keep chaining even if the last target died.
	end
	return hitAny
end

function Electric.Init(query: EnemyQuery, damage: DamageHandler)
	if queryEnemies then return end
	assert(RunService:IsServer(), "Electric must run on the server")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects"):WaitForChild("PlaySpecialEffect")
	assert(remote:IsA("RemoteEvent"), "Electric effects remote is missing")
	queryEnemies = query
	applyDamage = damage
	effectsRemote = remote
end

function Electric.Destroy()
	queryEnemies = nil
	applyDamage = nil
	effectsRemote = nil
end

return Electric
