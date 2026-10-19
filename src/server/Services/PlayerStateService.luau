--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UpgradeConfig"))

export type PlayerState = { Level: number, CurrentXP: number, RequiredXP: number, Upgrades: { [string]: number } }

local states: { [Player]: PlayerState } = {}
local connections: { RBXScriptConnection } = {}
local experienceChanged = Instance.new("BindableEvent")
local upgradeChanged = Instance.new("BindableEvent")
local started = false
local PlayerStateService = { ExperienceChanged = experienceChanged.Event, UpgradeChanged = upgradeChanged.Event }

local function PublishState(player: Player, state: PlayerState)
	-- Display/debug mirrors only. Clients cannot grant XP through attributes.
	player:SetAttribute("Level", state.Level)
	player:SetAttribute("CurrentXP", state.CurrentXP)
	player:SetAttribute("RequiredXP", state.RequiredXP)
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
	for _, id in UpgradeConfig.GetUpgradeIds() do
		player:SetAttribute("Upgrade_" .. id, nil)
	end
end

function PlayerStateService.GetState(player: Player): PlayerState?
	local state = states[player]
	return if state then table.freeze({
		Level = state.Level, CurrentXP = state.CurrentXP, RequiredXP = state.RequiredXP,
		Upgrades = table.freeze(table.clone(state.Upgrades)),
	}) else nil
end

-- Trusted server commit; ProgressionService validates the outstanding offer first.
function PlayerStateService.ApplyUpgrade(player: Player, upgradeId: string): boolean
	assert(RunService:IsServer(), "Upgrades must be granted on the server")
	local state = states[player]
	local definition = UpgradeConfig.GetUpgradeConfig(upgradeId)
	if not started or not state or player.Parent ~= Players or not definition then
		return false
	end
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
	for player in states do
		RemovePlayer(player)
	end
end

return PlayerStateService
