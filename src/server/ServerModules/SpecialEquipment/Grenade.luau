--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GrenadeConfig"))
local SpecialStats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("SpecialStats"))
local PlayerStateService = require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

type DamageHandler = (Model, number, Player?) -> boolean
type EnemyQuery = (Vector3, number) -> { Model }
type Projectile = {
	Owner: Player, Character: Model, Part: Part, Position: Vector3, Velocity: Vector3,
	FuseAt: number, UpdatedAt: number, Params: RaycastParams, Exploded: boolean,
	Damage: number, BlastRadius: number,
}
local Grenade = {}
local started = false
local projectiles: { [Part]: Projectile } = {}
local connections: { RBXScriptConnection } = {}
local container: Folder? = nil
local effectsRemote: RemoteEvent? = nil
local applyDamage: DamageHandler? = nil
local queryEnemies: EnemyQuery? = nil

local function Remove(projectile: Projectile)
	projectiles[projectile.Part] = nil
	projectile.Part:Destroy()
end

local function Explode(projectile: Projectile, position: Vector3)
	if projectile.Exploded or projectiles[projectile.Part] ~= projectile then return end
	-- Consume the projectile before damage/death callbacks can re-enter.
	projectile.Exploded = true
	Remove(projectile)
	local query = queryEnemies
	local damage = applyDamage
	if query and damage then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excluded: { Instance } = { projectile.Character }
		if container then table.insert(excluded, container) end
		local enemies = Workspace:FindFirstChild("EnemyContainer")
		local markers = Workspace:FindFirstChild("SpawnPoints")
		if enemies then table.insert(excluded, enemies) end
		if markers then table.insert(excluded, markers) end
		params.FilterDescendantsInstances = excluded
		params.RespectCanCollide = true
		local damaged: { [Model]: boolean } = {}
		for _, enemy in query(position, projectile.BlastRadius) do
			local root = enemy.PrimaryPart
			if damaged[enemy] or not root or (root.Position - position).Magnitude > projectile.BlastRadius then continue end
			damaged[enemy] = true
			local offset = root.Position - position
			if Config.RequireBlastLineOfSight and offset.Magnitude > 0 and Workspace:Raycast(position, offset, params) then continue end
			damage(enemy, projectile.Damage, projectile.Owner)
		end
	end
	if effectsRemote then
		effectsRemote:FireAllClients({ SpecialId = "Grenade", Event = "Exploded", Position = position, Radius = projectile.BlastRadius })
	end
end

local function Update()
	local now = Workspace:GetServerTimeNow()
	for part, projectile in projectiles do
		if not container or not part:IsDescendantOf(container) or projectile.Owner.Parent ~= Players then
			Remove(projectile)
			continue
		end
		-- Integrate only up to the fuse deadline, including after a slow server frame.
		local targetTime = math.min(now, projectile.FuseAt)
		while projectiles[part] and projectile.UpdatedAt < targetTime do
			local dt = math.min(Config.MaxSimulationStep, targetTime - projectile.UpdatedAt)
			local gravity = Vector3.new(0, -Workspace.Gravity * Config.GravityScale, 0)
			local displacement = projectile.Velocity * dt + gravity * (0.5 * dt * dt)
			local hit = if displacement.Magnitude > 0 then Workspace:Spherecast(projectile.Position, Config.Diameter / 2, displacement, projectile.Params) else nil
			if hit then
				Explode(projectile, hit.Position + hit.Normal * (Config.Diameter / 2 + Config.CollisionPadding))
			else
				projectile.Position += displacement
				projectile.Velocity += gravity * dt
				projectile.UpdatedAt += dt
				part.Position = projectile.Position
			end
		end
		if projectiles[part] and now >= projectile.FuseAt then Explode(projectile, projectile.Position) end
	end
end

local function Throw(player: Player, direction: Vector3, stats: SpecialStats.GrenadeStats)
	local character = player.Character
	assert(character, "Grenade requires a character")
	local root = character:FindFirstChild("HumanoidRootPart")
	assert(root and root:IsA("BasePart"), "Grenade requires a living root")
	local head = character:FindFirstChild("Head")
	local anchor = if head and head:IsA("BasePart") then head.Position else root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local excluded: { Instance } = { character }
	if container then table.insert(excluded, container) end
	local markers = Workspace:FindFirstChild("SpawnPoints")
	if markers then table.insert(excluded, markers) end
	params.FilterDescendantsInstances = excluded
	-- Sweep the launch offset too, so a throw cannot start on the far side of cover.
	local offset = direction * Config.LaunchOffset
	local hit = Workspace:Spherecast(anchor, Config.Diameter / 2, offset, params)
	local position = if hit then hit.Position + hit.Normal * (Config.Diameter / 2 + Config.CollisionPadding) else anchor + offset
	local part = Instance.new("Part")
	part.Name = "Grenade"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * Config.Diameter
	part.Color = Config.ProjectileColor
	part.Material = Enum.Material.Metal
	part.Anchored = true -- Kinematic flight/collision is simulated only on the server.
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Position = position
	part.Parent = container
	local now = Workspace:GetServerTimeNow()
	local projectile: Projectile = {
		Owner = player, Character = character, Part = part, Position = position,
		Velocity = direction * Config.ThrowSpeed + Vector3.new(0, Config.UpwardSpeed, 0),
		FuseAt = now + Config.FuseTime, UpdatedAt = now, Params = params, Exploded = false,
		Damage = stats.Damage, BlastRadius = stats.BlastRadius,
	}
	projectiles[part] = projectile
	if hit then Explode(projectile, position) end
end

function Grenade.Use(player: Player, _level: number, direction: Vector3)
	assert(started and RunService:IsServer(), "Grenade must be initialized on the server")
	local state = PlayerStateService.GetState(player)
	assert(state and state.CurrentSpecial == "Grenade", "Grenade requires server-owned equipment")
	local stats = SpecialStats.GetGrenadeStats(state.Upgrades)
	-- One Q reserves one cooldown. All projectiles keep the same use-time stat snapshot.
	for index = 1, stats.Count do
		local angle = math.rad((index - (stats.Count + 1) / 2) * Config.MultiAngleStep)
		local aimed = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(direction)
		Throw(player, aimed, stats)
	end
end

function Grenade.Init(query: EnemyQuery, damage: DamageHandler)
	if started then return end
	assert(RunService:IsServer(), "Grenade must run on the server")
	local folder = Workspace:WaitForChild("ProjectileContainer")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects"):WaitForChild("PlaySpecialEffect")
	assert(folder:IsA("Folder") and remote:IsA("RemoteEvent"), "Grenade dependencies are missing")
	if started then return end
	container = folder
	effectsRemote = remote
	queryEnemies = query
	applyDamage = damage
	started = true
	table.insert(connections, RunService.Heartbeat:Connect(Update))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		for _, projectile in projectiles do
			if projectile.Owner == player then Remove(projectile) end
		end
	end))
end

function Grenade.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for _, projectile in projectiles do Remove(projectile) end
	container = nil
	effectsRemote = nil
	queryEnemies = nil
	applyDamage = nil
end

return Grenade
