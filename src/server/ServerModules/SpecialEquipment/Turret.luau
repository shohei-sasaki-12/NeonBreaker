--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("TurretConfig"))
local PlayerStateService = require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

type EnemyQuery = (Vector3, number) -> { Model }
type DamageHandler = (Model, number, Player?, Vector3) -> boolean
type TurretState = {
	Owner: Player, Character: Model, Model: Model, Barrel: Part, Origin: Vector3,
	ExpiresAt: number, NextShotAt: number,
}
local turrets: { [Player]: TurretState } = {}
local connections: { RBXScriptConnection } = {}
local container: Folder? = nil
local effectsRemote: RemoteEvent? = nil
local queryEnemies: EnemyQuery? = nil
local applyDamage: DamageHandler? = nil
local started = false
local Turret = {}

local function Remove(player: Player)
	local record = turrets[player]
	if not record then return end
	turrets[player] = nil
	record.Model:Destroy()
end

local function MakePart(name: string, size: Vector3, color: Color3, parent: Model): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = parent
	return part
end

local function RayParams(character: Model, placement: boolean): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local excluded: { Instance } = { character }
	if container then table.insert(excluded, container) end
	local markers = Workspace:FindFirstChild("SpawnPoints")
	if markers then table.insert(excluded, markers) end
	if placement then
		local enemies = Workspace:FindFirstChild("EnemyContainer")
		if enemies then table.insert(excluded, enemies) end
		for _, player in Players:GetPlayers() do
			if player.Character then table.insert(excluded, player.Character) end
		end
	end
	params.FilterDescendantsInstances = excluded
	return params
end

local function FindTarget(record: TurretState): (Model?, Vector3?)
	local query = queryEnemies
	if not query then return nil, nil end
	local nearest: Model? = nil
	local targetPosition: Vector3? = nil
	local nearestDistance = math.huge
	local params = RayParams(record.Character, false)
	for _, enemy in query(record.Origin, Config.Range) do
		local root = enemy.PrimaryPart
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then continue end
		local offset = root.Position - record.Origin
		local distance = offset.Magnitude
		if distance > Config.Range or distance >= nearestDistance then continue end
		local hit = if distance > 0 then Workspace:Raycast(record.Origin, offset, params) else nil
		if hit and not hit.Instance:IsDescendantOf(enemy) then continue end
		nearest = enemy
		targetPosition = root.Position
		nearestDistance = distance
	end
	return nearest, targetPosition
end

local function Update()
	local now = Workspace:GetServerTimeNow()
	for player, record in turrets do
		local state = PlayerStateService.GetState(player)
		local humanoid = record.Character:FindFirstChildOfClass("Humanoid")
		if not container or not record.Model:IsDescendantOf(container) or player.Parent ~= Players
			or not state or state.CurrentSpecial ~= "Turret" or player.Character ~= record.Character
			or not record.Character.Parent or not humanoid or humanoid.Health <= 0 or now >= record.ExpiresAt then
			Remove(player)
			continue
		end
		if now < record.NextShotAt then continue end
		-- No catch-up burst after slow frames, and no shots at/after expiry.
		record.NextShotAt = now + Config.FireInterval
		local target, position = FindTarget(record)
		local damage = applyDamage
		if target and position and damage then
			if (position - record.Origin).Magnitude > 0 then
				record.Barrel.CFrame = CFrame.lookAt(record.Origin, position) * CFrame.new(0, 0, -Config.BarrelSize.Z / 2)
			end
			if damage(target, Config.Damage, player, record.Origin) and effectsRemote then
				effectsRemote:FireAllClients({ SpecialId = "Turret", Event = "Fired", Origin = record.Origin, Position = position })
			end
		end
	end
end

function Turret.Use(player: Player, _level: number, _direction: Vector3)
	assert(started and RunService:IsServer(), "Turret must be initialized on the server")
	local state = PlayerStateService.GetState(player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	assert(state and state.CurrentSpecial == "Turret" and character and character.Parent
		and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0, "Turret requires a living owner")
	local ground = Workspace:Raycast(root.Position, Vector3.new(0, -Config.GroundProbeDistance, 0), RayParams(character, true))
	assert(ground, "Turret requires ground below the player")
	Remove(player)
	local model = Instance.new("Model")
	model.Name = "Turret"
	model:SetAttribute("OwnerUserId", player.UserId)
	local now = Workspace:GetServerTimeNow()
	model:SetAttribute("ExpiresAt", now + Config.Duration)
	local base = MakePart("Base", Config.BaseSize, Config.BaseColor, model)
	base.Position = ground.Position + Vector3.new(0, Config.BaseSize.Y / 2, 0)
	model.PrimaryPart = base
	local origin = ground.Position + Vector3.new(0, Config.GunHeight, 0)
	local barrel = MakePart("Barrel", Config.BarrelSize, Config.BarrelColor, model)
	barrel.CFrame = CFrame.new(origin) * CFrame.new(0, 0, -Config.BarrelSize.Z / 2)
	model.Parent = container
	turrets[player] = {
		Owner = player, Character = character, Model = model, Barrel = barrel, Origin = origin,
		ExpiresAt = now + Config.Duration, NextShotAt = now,
	}
end

function Turret.Init(query: EnemyQuery, damage: DamageHandler)
	if started then return end
	assert(RunService:IsServer(), "Turret must run on the server")
	local folder = Workspace:WaitForChild("ProjectileContainer")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects"):WaitForChild("PlaySpecialEffect")
	assert(folder:IsA("Folder") and remote:IsA("RemoteEvent"), "Turret dependencies are missing")
	container = folder
	effectsRemote = remote
	queryEnemies = query
	applyDamage = damage
	started = true
	table.insert(connections, RunService.Heartbeat:Connect(Update))
	table.insert(connections, Players.PlayerRemoving:Connect(Remove))
end

function Turret.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for player in turrets do Remove(player) end
	container = nil
	effectsRemote = nil
	queryEnemies = nil
	applyDamage = nil
end

return Turret
