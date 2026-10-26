--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UpgradeConfig"))
local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local WeaponConfig = require(ConfigFolder:WaitForChild("WeaponConfig"))
local CombatConfig = require(ConfigFolder:WaitForChild("CombatConfig"))
local SelectionConfig = require(ConfigFolder:WaitForChild("WeaponSelectionConfig"))
local SpecialConfig = require(ConfigFolder:WaitForChild("SpecialEquipmentConfig"))
local Workspace = game:GetService("Workspace")

export type PlayerState = {
	Level: number, CurrentXP: number, RequiredXP: number, Upgrades: { [string]: number },
	CurrentWeaponId: string, HasSelectedWeapon: boolean,
	CurrentSpecial: string?, SpecialCooldown: number, SpecialLevel: number,
}

local states: { [Player]: PlayerState } = {}
local connections: { RBXScriptConnection } = {}
local experienceChanged = Instance.new("BindableEvent")
local upgradeChanged = Instance.new("BindableEvent")
local weaponChanged = Instance.new("BindableEvent")
local specialChanged = Instance.new("BindableEvent")
local started = false
local weaponSelectionLocked = false
local PlayerStateService = {
	ExperienceChanged = experienceChanged.Event, UpgradeChanged = upgradeChanged.Event, WeaponChanged = weaponChanged.Event,
	SpecialChanged = specialChanged.Event,
}

local function PublishState(player: Player, state: PlayerState)
	-- Display/debug mirrors only. Clients cannot grant XP through attributes.
	player:SetAttribute("Level", state.Level)
	player:SetAttribute("CurrentXP", state.CurrentXP)
	player:SetAttribute("RequiredXP", state.RequiredXP)
	player:SetAttribute("CurrentWeaponId", state.CurrentWeaponId)
	player:SetAttribute("HasSelectedWeapon", state.HasSelectedWeapon)
	player:SetAttribute("CurrentSpecial", state.CurrentSpecial)
	player:SetAttribute("SpecialCooldown", state.SpecialCooldown)
	player:SetAttribute("SpecialLevel", state.SpecialLevel)
	for id, level in state.Upgrades do
		player:SetAttribute("Upgrade_" .. id, level)
	end
end

local function AddPlayer(player: Player)
	if not states[player] then
		local state: PlayerState = {
			Level = Config.InitialLevel,
			CurrentXP = 0,
			RequiredXP = Config.GetRequiredXP(Config.InitialLevel),
			Upgrades = {},
			CurrentWeaponId = CombatConfig.DefaultWeaponId,
			HasSelectedWeapon = false,
			CurrentSpecial = nil,
			SpecialCooldown = 0, -- Server-time deadline, not a client-maintained countdown.
			SpecialLevel = 0,
		}
		for _, id in UpgradeConfig.GetUpgradeIds() do
			state.Upgrades[id] = 0
		end
		states[player] = state
		PublishState(player, state)
	end
end

local function RemovePlayer(player: Player)
	states[player] = nil
	player:SetAttribute("Level", nil)
	player:SetAttribute("CurrentXP", nil)
	player:SetAttribute("RequiredXP", nil)
	player:SetAttribute("CurrentWeaponId", nil)
	player:SetAttribute("HasSelectedWeapon", nil)
	player:SetAttribute("CurrentSpecial", nil)
	player:SetAttribute("SpecialCooldown", nil)
	player:SetAttribute("SpecialLevel", nil)
	for _, id in UpgradeConfig.GetUpgradeIds() do
		player:SetAttribute("Upgrade_" .. id, nil)
	end
end

function PlayerStateService.GetState(player: Player): PlayerState?
	local state = states[player]
	return if state then table.freeze({
		Level = state.Level, CurrentXP = state.CurrentXP, RequiredXP = state.RequiredXP,
		Upgrades = table.freeze(table.clone(state.Upgrades)),
		CurrentWeaponId = state.CurrentWeaponId, HasSelectedWeapon = state.HasSelectedWeapon,
		CurrentSpecial = state.CurrentSpecial, SpecialCooldown = state.SpecialCooldown, SpecialLevel = state.SpecialLevel,
	}) else nil
end

-- Trusted server grant/update API. No Remote equips special equipment.
function PlayerStateService.SetSpecial(player: Player, specialId: string?, level: number): boolean
	assert(RunService:IsServer(), "Special equipment must be granted on the server")
	local state = states[player]
	if not started or not state or player.Parent ~= Players then return false end
	if specialId == nil then
		if level ~= 0 then return false end
	else
		local definition = SpecialConfig.GetSpecialConfig(specialId)
		if not definition or level ~= level or level % 1 ~= 0 or level < 1 or level > definition.MaxLevel then return false end
	end
	state.CurrentSpecial = specialId
	state.SpecialLevel = level
	-- Retain any existing deadline so changing/unequipping cannot bypass cooldown.
	player:SetAttribute("CurrentSpecial", specialId)
	player:SetAttribute("SpecialLevel", level)
	specialChanged:Fire(player)
	return true
end

-- Atomic reservation; SpecialEquipmentService checks life and registered behavior first.
function PlayerStateService.TryStartSpecialCooldown(player: Player, specialId: string, level: number): boolean
	assert(RunService:IsServer(), "Special cooldown must be started on the server")
	local state = states[player]
	local definition = SpecialConfig.GetSpecialConfig(specialId)
	if not started or not state or player.Parent ~= Players or not definition
		or state.CurrentSpecial ~= specialId or state.SpecialLevel ~= level or level < 1 or level > definition.MaxLevel then
		return false
	end
	local duration = definition.Cooldown
	if duration ~= duration or duration < 0 or duration == math.huge then return false end
	local now = Workspace:GetServerTimeNow()
	if now < state.SpecialCooldown then return false end
	state.SpecialCooldown = now + duration
	player:SetAttribute("SpecialCooldown", state.SpecialCooldown)
	specialChanged:Fire(player)
	return true
end

-- StageService owns the selection window; no client-supplied state can unlock it.
function PlayerStateService.SetWeaponSelectionLocked(locked: boolean)
	assert(RunService:IsServer(), "Weapon selection lock must be set on the server")
	weaponSelectionLocked = locked
end

function PlayerStateService.TrySelectWeapon(player: Player, weaponId: any): boolean
	assert(RunService:IsServer(), "Weapons must be selected on the server")
	local state = states[player]
	if not started or weaponSelectionLocked or not state or player.Parent ~= Players
		or typeof(weaponId) ~= "string" or not table.find(SelectionConfig.WeaponIds, weaponId)
		or not WeaponConfig.GetWeaponConfig(weaponId) then
		return false
	end
	local changedWeapon = state.CurrentWeaponId ~= weaponId
	state.CurrentWeaponId = weaponId
	state.HasSelectedWeapon = true
	player:SetAttribute("CurrentWeaponId", weaponId)
	player:SetAttribute("HasSelectedWeapon", true)
	if changedWeapon then weaponChanged:Fire(player, weaponId) end
	return true
end

-- Trusted server commit; ProgressionService validates the outstanding offer first.
function PlayerStateService.ApplyUpgrade(player: Player, upgradeId: string): boolean
	assert(RunService:IsServer(), "Upgrades must be granted on the server")
	local state = states[player]
	local definition = UpgradeConfig.GetUpgradeConfig(upgradeId)
	if not started or not state or player.Parent ~= Players or not definition then
		return false
	end
	if not UpgradeConfig.CanApplyUpgrade(upgradeId, state.CurrentWeaponId, state.Upgrades) then return false end
	local current = state.Upgrades[upgradeId] or 0
	if current >= definition.MaxLevel then
		return false
	end
	state.Upgrades[upgradeId] = current + 1
	player:SetAttribute("Upgrade_" .. upgradeId, current + 1)
	upgradeChanged:Fire(player, upgradeId, current + 1)
	return true
end

-- Server-only commit API. XP grants go through ProgressionService.AddExperience.
function PlayerStateService.UpdateProgression(player: Player, level: number, currentXP: number, amount: number): boolean
	assert(RunService:IsServer(), "Progression state must be updated on the server")
	local state = states[player]
	if not started or not state or player.Parent ~= Players
		or amount ~= amount or amount <= 0 or amount == math.huge or amount % 1 ~= 0
		or level ~= level or level < state.Level or level == math.huge or level % 1 ~= 0
		or currentXP ~= currentXP or currentXP < 0 or currentXP == math.huge or currentXP % 1 ~= 0 then
		return false
	end
	local requiredXP = Config.GetRequiredXP(level)
	if currentXP >= requiredXP then
		return false
	end
	state.Level = level
	state.CurrentXP = currentXP
	state.RequiredXP = requiredXP
	local snapshot = table.freeze({
		Level = level, CurrentXP = currentXP, RequiredXP = requiredXP,
		Upgrades = table.freeze(table.clone(state.Upgrades)),
		CurrentWeaponId = state.CurrentWeaponId, HasSelectedWeapon = state.HasSelectedWeapon,
		CurrentSpecial = state.CurrentSpecial, SpecialCooldown = state.SpecialCooldown, SpecialLevel = state.SpecialLevel,
	})
	PublishState(player, snapshot)
	-- Keep the original first three arguments; append the committed snapshot.
	experienceChanged:Fire(player, currentXP, amount, snapshot)
	return true
end

function PlayerStateService.Init()
	if started then
		return
	end
	assert(RunService:IsServer(), "PlayerStateService must run on the server")
	started = true
	table.insert(connections, Players.PlayerAdded:Connect(AddPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(RemovePlayer))
	for _, player in Players:GetPlayers() do
		AddPlayer(player)
	end
end

function PlayerStateService.Destroy()
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	weaponSelectionLocked = false
	for player in states do
		RemovePlayer(player)
	end
end

return PlayerStateService
