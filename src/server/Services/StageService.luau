--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StageConfig"))

export type StageState = "Waiting" | "Countdown" | "Running" | "Cleared" | "GameOver"
export type Snapshot = {
	StageId: string, State: StageState, RemainingSeconds: number, EndsAt: number?,
}
type Participant = { Character: Model, Humanoid: Humanoid, Eliminated: boolean }

local changed = Instance.new("BindableEvent")
local StageService = { StateChanged = changed.Event }
local state: StageState = "Waiting"
local endsAt: number? = nil
local started = false
local lastRemaining = -1
local stateRemote: RemoteEvent? = nil
local timerRemote: RemoteEvent? = nil
local participants: { [Player]: Participant } = {}
local connections: { RBXScriptConnection } = {}
local deathConnections: { RBXScriptConnection } = {}
local nextRequestAt: { [Player]: number } = {}

function StageService.GetState(): Snapshot
	return table.freeze({
		StageId = Config.StageId,
		State = state,
		RemainingSeconds = if endsAt then math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())) else 0,
		EndsAt = endsAt,
	})
end

local function DisconnectDeaths()
	for _, connection in deathConnections do connection:Disconnect() end
	table.clear(deathConnections)
end

local function Transition(nextState: StageState, deadline: number?)
	state = nextState
	endsAt = deadline
	local snapshot = StageService.GetState()
	lastRemaining = snapshot.RemainingSeconds
	if nextState == "Cleared" or nextState == "GameOver" then DisconnectDeaths() end
	print("[StageService] " .. nextState)
	if stateRemote then stateRemote:FireAllClients(snapshot) end
	if timerRemote then timerRemote:FireAllClients(snapshot) end
	changed:Fire(snapshot)
end

local function GetReadyPlayers(): { [Player]: Participant }?
	local players = Players:GetPlayers()
	if #players == 0 then return nil end
	local ready: { [Player]: Participant } = {}
	for _, player in players do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not character or not character.Parent or not humanoid or humanoid.Health <= 0 then return nil end
		ready[player] = { Character = character, Humanoid = humanoid, Eliminated = false }
	end
	return ready
end

local function HasLivingParticipant(): boolean
	local alive = false
	for player, record in participants do
		-- Latch elimination: Roblox's automatic respawn cannot undo a run death.
		if player.Parent ~= Players or player.Character ~= record.Character
			or not record.Character.Parent or record.Humanoid.Parent ~= record.Character
			or record.Humanoid.Health <= 0 then
			record.Eliminated = true
		end
		if not record.Eliminated then alive = true end
	end
	return alive
end

local function Update()
	local now = Workspace:GetServerTimeNow()
	if state == "Waiting" then
		if GetReadyPlayers() then Transition("Countdown", now + Config.CountdownDuration) end
	elseif state == "Countdown" then
		local ready = GetReadyPlayers()
		if not ready then
			Transition("Waiting", nil)
		elseif endsAt and now >= endsAt then
			participants = ready
			for _, record in participants do
				table.insert(deathConnections, record.Humanoid.Died:Connect(function()
					record.Eliminated = true
				end))
			end
			-- Use deadlines rather than subtracting frame deltas, avoiding drift.
			Transition("Running", now + Config.RunningDuration)
		end
	elseif state == "Running" then
		-- A wipe takes precedence if the deadline and last death share an update.
		if not HasLivingParticipant() then
			Transition("GameOver", nil)
		elseif endsAt and now >= endsAt then
			Transition("Cleared", nil)
		end
	end
	if state == "Countdown" or state == "Running" then
		local snapshot = StageService.GetState()
		if snapshot.RemainingSeconds ~= lastRemaining then
			lastRemaining = snapshot.RemainingSeconds
			if timerRemote then timerRemote:FireAllClients(snapshot) end
		end
	end
end

function StageService.Init()
	if started then return end
	assert(RunService:IsServer(), "StageService must run on the server")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Stage")
	local stateEvent = remotes:WaitForChild("StageStateChanged")
	local timerEvent = remotes:WaitForChild("StageTimerUpdated")
	assert(stateEvent:IsA("RemoteEvent") and timerEvent:IsA("RemoteEvent"), "Stage remotes must be RemoteEvents")
	if started then return end
	started = true
	stateRemote = stateEvent
	timerRemote = timerEvent
	Transition("Waiting", nil)
	-- Snapshot requests carry no state or timer values; late subscribers can sync.
	table.insert(connections, stateEvent.OnServerEvent:Connect(function(player: Player)
		if player.Parent ~= Players then return end
		local now = Workspace:GetServerTimeNow()
		if now < (nextRequestAt[player] or 0) then return end
		nextRequestAt[player] = now + Config.SnapshotRequestInterval
		local snapshot = StageService.GetState()
		stateEvent:FireClient(player, snapshot)
		timerEvent:FireClient(player, snapshot)
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		nextRequestAt[player] = nil
		local record = participants[player]
		if record then record.Eliminated = true end
	end))
	table.insert(connections, RunService.Heartbeat:Connect(Update))
end

function StageService.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	DisconnectDeaths()
	table.clear(participants)
	table.clear(nextRequestAt)
	stateRemote = nil
	timerRemote = nil
	state = "Waiting"
	endsAt = nil
	lastRemaining = -1
end

return StageService
