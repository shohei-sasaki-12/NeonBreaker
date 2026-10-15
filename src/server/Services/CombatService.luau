--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local WeaponConfig = require(ConfigFolder:WaitForChild("WeaponConfig"))
local Config = require(ConfigFolder:WaitForChild("CombatConfig"))
local Validation = require(script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("CombatValidation"))

type PlayerWeapon = {
	Character: Model?,
	WeaponId: string,
	Ammo: number,
	ReloadEndsAt: number?,
	NextShotAt: number,
	LastShotId: number,
	LastReloadId: number,
	Revision: number,
	Tokens: number,
	TokenTime: number,
	Connections: { RBXScriptConnection },
}

local CombatService = {}
local states: { [Player]: PlayerWeapon } = {}
local connections: { RBXScriptConnection } = {}
local stateRemote: RemoteEvent? = nil
local started = false

local function SendState(player: Player, state: PlayerWeapon)
	local remote = stateRemote
	if not remote then
		return
	end
	state.Revision += 1
	remote:FireClient(player, {
		Character = state.Character,
		WeaponId = state.WeaponId,
		Ammo = state.Ammo,
		IsReloading = state.ReloadEndsAt ~= nil,
		AckShotId = state.LastShotId,
		AckReloadId = state.LastReloadId,
		Revision = state.Revision,
	})
end

local function AllowRequest(player: Player, now: number): PlayerWeapon?
	local state = states[player]
	if not state then
		return nil
	end
	state.Tokens = math.min(Config.RemoteBurstSize, state.Tokens + (now - state.TokenTime) * Config.RemoteRequestsPerSecond)
	state.TokenTime = now
	if state.Tokens < 1 then
		return nil
	end
	state.Tokens -= 1
	return state
end

local function UpdateReload(player: Player, state: PlayerWeapon, now: number)
	local deadline = state.ReloadEndsAt
	if deadline == nil then
		return
	end
	if not Validation.GetLivingRoot(player, state.Character) then
		state.ReloadEndsAt = nil
		SendState(player, state)
	elseif now >= deadline then
		local config = WeaponConfig.GetWeaponConfig(state.WeaponId)
		assert(config, "Equipped weapon is missing from WeaponConfig")
		state.ReloadEndsAt = nil
		state.Ammo = config.MagazineSize
		SendState(player, state)
	end
end

local function OnFire(player: Player, weaponId: any, origin: any, direction: any, shotId: any)
	local now = os.clock()
	local state = AllowRequest(player, now)
	if not state or not Validation.IsSequenceId(shotId) or shotId <= state.LastShotId then
		return
	end
	UpdateReload(player, state, now)
	state.LastShotId = shotId
	local root = Validation.GetLivingRoot(player, state.Character)
	local config = if typeof(weaponId) == "string" then WeaponConfig.GetWeaponConfig(weaponId) else nil
	if not root or weaponId ~= state.WeaponId or not config
		or state.ReloadEndsAt ~= nil or state.Ammo <= 0 or now + Config.FireTimingTolerance < state.NextShotAt
		or not Validation.IsVector(origin) or not Validation.IsDirection(direction)
		or (origin - root.Position).Magnitude > Config.MaxOriginDistance then
		SendState(player, state)
		return
	end

	local params = RaycastParams.new()
	local character = state.Character :: Model
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	-- A camera origin cannot bypass an obstacle between the character and camera.
	local head = character:FindFirstChild("Head")
	local anchor = if head and head:IsA("BasePart") then head.Position else root.Position
	local toOrigin = origin - anchor
	if toOrigin.Magnitude > 0 and Workspace:Raycast(anchor, toOrigin, params) then
		SendState(player, state)
		return
	end
	state.Ammo -= 1
	-- Carry timing debt forward: jitter tolerance cannot increase sustained fire rate.
	state.NextShotAt = math.max(now, state.NextShotAt) + config.FireInterval
	local hit = Workspace:Raycast(origin, direction.Unit * config.Range, params)
	if hit and Config.LogHits then
		print(string.format("[CombatService] %s hit %s (shot %d)", player.Name, hit.Instance.Name, shotId))
	end
	SendState(player, state)
end

local function OnReload(player: Player, weaponId: any, reloadId: any)
	local now = os.clock()
	local state = AllowRequest(player, now)
	if not state or not Validation.IsSequenceId(reloadId) or reloadId <= state.LastReloadId then
		return
	end
	UpdateReload(player, state, now)
	state.LastReloadId = reloadId
	local config = if typeof(weaponId) == "string" then WeaponConfig.GetWeaponConfig(weaponId) else nil
	if Validation.GetLivingRoot(player, state.Character) and config and weaponId == state.WeaponId
		and state.ReloadEndsAt == nil and state.Ammo < config.MagazineSize then
		state.ReloadEndsAt = now + config.ReloadTime
	end
	SendState(player, state)
end

local function RemovePlayer(player: Player)
	local state = states[player]
	if state then
		for _, connection in state.Connections do
			connection:Disconnect()
		end
		states[player] = nil
	end
end

local function AddPlayer(player: Player)
	if states[player] then
		return
	end
	local config = WeaponConfig.GetWeaponConfig(Config.DefaultWeaponId)
	assert(config, "Default weapon is missing from WeaponConfig")
	local state: PlayerWeapon = {
		Character = nil, WeaponId = config.WeaponId, Ammo = config.MagazineSize,
		ReloadEndsAt = nil, NextShotAt = 0, LastShotId = 0, LastReloadId = 0,
		Revision = 0, Tokens = Config.RemoteBurstSize, TokenTime = os.clock(), Connections = {},
	}
	states[player] = state
	-- Until PlayerStateService exists, CombatService owns the default equipment.
	local function OnCharacterAdded(character: Model)
		state.Character = character
		state.WeaponId = config.WeaponId
		state.Ammo = config.MagazineSize
		state.ReloadEndsAt = nil
		state.NextShotAt = 0
		SendState(player, state)
	end
	table.insert(state.Connections, player.CharacterAdded:Connect(OnCharacterAdded))
	table.insert(state.Connections, player.CharacterRemoving:Connect(function(character: Model)
		if state.Character == character then
			state.Character = nil
			state.ReloadEndsAt = nil
		end
	end))
	if player.Character then
		OnCharacterAdded(player.Character)
	end
end

-- Server-only entry point for enemy attacks. No damage Remote is exposed.
function CombatService.ApplyEnemyDamage(player: Player, amount: number): boolean
	assert(RunService:IsServer(), "Enemy damage must run on the server")
	if not started or not Validation.IsFinite(amount) or amount <= 0 then
		return false
	end
	local state = states[player]
	if not state or not Validation.GetLivingRoot(player, state.Character) then
		return false
	end
	local character = state.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	humanoid:TakeDamage(amount)
	return true
end

function CombatService.Init()
	if started then
		return
	end
	assert(RunService:IsServer(), "CombatService must run on the server")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat")
	local fire = remotes:WaitForChild("FireWeapon")
	local reload = remotes:WaitForChild("ReloadWeapon")
	local snapshot = remotes:WaitForChild("WeaponStateChanged")
	assert(fire:IsA("RemoteEvent") and reload:IsA("RemoteEvent") and snapshot:IsA("RemoteEvent"), "Combat remotes must be RemoteEvents")
	if started then
		return
	end
	started = true
	stateRemote = snapshot
	table.insert(connections, Players.PlayerAdded:Connect(AddPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(RemovePlayer))
	for _, player in Players:GetPlayers() do
		AddPlayer(player)
	end
	table.insert(connections, fire.OnServerEvent:Connect(OnFire))
	table.insert(connections, reload.OnServerEvent:Connect(OnReload))
	-- A client can request a snapshot, but never supplies state values.
	table.insert(connections, snapshot.OnServerEvent:Connect(function(player: Player)
		local state = AllowRequest(player, os.clock())
		if state then
			SendState(player, state)
		end
	end))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, state in states do
			UpdateReload(player, state, now)
		end
	end))
end

function CombatService.Destroy()
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for player in states do
		RemovePlayer(player)
	end
	stateRemote = nil
end

return CombatService
