--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ProgressionConfig"))

export type PlayerState = { Level: number, CurrentXP: number, RequiredXP: number }

local states: { [Player]: PlayerState } = {}
local connections: { RBXScriptConnection } = {}
local experienceChanged = Instance.new("BindableEvent")
local started = false
local PlayerStateService = { ExperienceChanged = experienceChanged.Event }

local function PublishState(player: Player, state: PlayerState)
	-- Display/debug mirrors only. Clients cannot grant XP through attributes.
	player:SetAttribute("Level", state.Level)
	player:SetAttribute("CurrentXP", state.CurrentXP)
	player:SetAttribute("RequiredXP", state.RequiredXP)
end

local function AddPlayer(player: Player)
	if not states[player] then
		local state: PlayerState = {
			Level = Config.InitialLevel,
			CurrentXP = 0,
			RequiredXP = Config.GetRequiredXP(Config.InitialLevel),
		}
		states[player] = state
		PublishState(player, state)
	end
end

local function RemovePlayer(player: Player)
	states[player] = nil
	player:SetAttribute("Level", nil)
	player:SetAttribute("CurrentXP", nil)
	player:SetAttribute("RequiredXP", nil)
end

function PlayerStateService.GetState(player: Player): PlayerState?
	local state = states[player]
	return if state then table.freeze({ Level = state.Level, CurrentXP = state.CurrentXP, RequiredXP = state.RequiredXP }) else nil
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
	local snapshot = table.freeze({ Level = level, CurrentXP = currentXP, RequiredXP = requiredXP })
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
