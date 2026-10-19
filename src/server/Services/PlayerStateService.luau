--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type PlayerState = { CurrentXP: number }

local states: { [Player]: PlayerState } = {}
local connections: { RBXScriptConnection } = {}
local experienceChanged = Instance.new("BindableEvent")
local started = false
local PlayerStateService = { ExperienceChanged = experienceChanged.Event }

local function AddPlayer(player: Player)
	if not states[player] then
		states[player] = { CurrentXP = 0 }
		-- Display/debug mirror only. The private server table is authoritative.
		player:SetAttribute("CurrentXP", 0)
	end
end

local function RemovePlayer(player: Player)
	states[player] = nil
	player:SetAttribute("CurrentXP", nil)
end

function PlayerStateService.GetState(player: Player): PlayerState?
	local state = states[player]
	return if state then table.freeze({ CurrentXP = state.CurrentXP }) else nil
end

function PlayerStateService.AddExperience(player: Player, amount: number): boolean
	assert(RunService:IsServer(), "XP must be granted on the server")
	local state = states[player]
	if not started or not state or player.Parent ~= Players
		or amount ~= amount or amount <= 0 or amount == math.huge or amount % 1 ~= 0
		or state.CurrentXP + amount > 9007199254740991 then
		return false
	end
	state.CurrentXP += amount
	player:SetAttribute("CurrentXP", state.CurrentXP)
	experienceChanged:Fire(player, state.CurrentXP, amount)
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
