--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UpgradeConfig"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

type Offer = { Id: number, Level: number, Candidates: { string } }
type Choices = {
	Pending: number, LastLevel: number, Offer: Offer?,
	NextSelectAt: number, NextSyncAt: number,
}

local choices: { [Player]: Choices } = {}
local connections: { RBXScriptConnection } = {}
local availableRemote: RemoteEvent? = nil
local started = false
local random = Random.new()
local nextOfferId = 0 -- Never reuse an offer ID after a service restart or player exit.
local ProgressionService = {}

local function GetChoices(player: Player): Choices
	local record = choices[player]
	if not record then
		local state = PlayerStateService.GetState(player)
		local usedChoices = 0
		if state then
			for _, level in state.Upgrades do
				usedChoices += level
			end
		end
		record = {
			Pending = 0, LastLevel = Config.InitialLevel + usedChoices, Offer = nil,
			NextSelectAt = 0, NextSyncAt = 0,
		}
		choices[player] = record
	end
	return record
end

local function EnsureOffer(player: Player, record: Choices)
	if record.Offer or record.Pending <= 0 then
		return
	end
	local state = PlayerStateService.GetState(player)
	if not state then
		return
	end
	local candidates: { string } = {}
	for _, id in UpgradeConfig.GetUpgradeIds() do
		local definition = UpgradeConfig.GetUpgradeConfig(id)
		if definition and (state.Upgrades[id] or 0) < definition.MaxLevel then
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 then
		-- No duplicate/max-level filler choices when the minimal pool is exhausted.
		record.Pending = 0
		return
	end
	for i = #candidates, 2, -1 do
		local j = random:NextInteger(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	while #candidates > UpgradeConfig.ChoiceCount do
		table.remove(candidates)
	end
	nextOfferId += 1
	record.Offer = { Id = nextOfferId, Level = record.LastLevel - record.Pending + 1, Candidates = candidates }
end

function ProgressionService.GetPendingOffer(player: Player)
	local record = choices[player]
	local state = PlayerStateService.GetState(player)
	if not record or not state then
		return nil
	end
	local offer = record.Offer
	return table.freeze({
		OfferId = if offer then offer.Id else 0,
		Level = if offer then offer.Level else state.Level,
		Candidates = table.freeze(if offer then table.clone(offer.Candidates) else {}),
		PendingChoices = record.Pending,
		Upgrades = state.Upgrades,
	})
end

local function SendOffer(player: Player)
	local remote = availableRemote
	local packet = ProgressionService.GetPendingOffer(player)
	if remote and packet then
		remote:FireClient(player, packet)
	end
end

local function ObserveLevel(player: Player)
	local state = PlayerStateService.GetState(player)
	if not state then
		return
	end
	local record = GetChoices(player)
	if state.Level > record.LastLevel then
		record.Pending += state.Level - record.LastLevel
		record.LastLevel = state.Level
		EnsureOffer(player, record)
		SendOffer(player)
	end
end

function ProgressionService.AddExperience(player: Player, amount: number): boolean
	assert(RunService:IsServer(), "XP must be granted on the server")
	local state = PlayerStateService.GetState(player)
	if not started or not state or amount ~= amount or amount <= 0 or amount == math.huge or amount % 1 ~= 0
		or state.CurrentXP + amount > 9007199254740991 then
		return false
	end
	local level = state.Level
	local xp = state.CurrentXP + amount
	local requiredXP = Config.GetRequiredXP(level)
	while xp >= requiredXP do
		xp -= requiredXP
		level += 1
		requiredXP = Config.GetRequiredXP(level)
	end
	if not PlayerStateService.UpdateProgression(player, level, xp, amount) then
		return false
	end
	ObserveLevel(player)
	return true
end

local function SelectUpgrade(player: Player, offerId: any, upgradeId: any)
	local record = choices[player]
	if not record or player.Parent ~= Players then
		return
	end
	local now = os.clock()
	if now < record.NextSelectAt then
		return
	end
	record.NextSelectAt = now + UpgradeConfig.SelectInterval
	local offer = record.Offer
	if not offer or typeof(offerId) ~= "number" or offerId ~= offer.Id
		or typeof(upgradeId) ~= "string" or not table.find(offer.Candidates, upgradeId) then
		return
	end
	-- Consume the offer before upgrade notifications can re-enter selection.
	record.Offer = nil
	record.Pending -= 1
	if not PlayerStateService.ApplyUpgrade(player, upgradeId) then
		record.Pending += 1
		record.Offer = offer
		return
	end
	EnsureOffer(player, record)
	SendOffer(player)
end

function ProgressionService.Init()
	if started then
		return
	end
	assert(RunService:IsServer(), "ProgressionService must run on the server")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Progression")
	local available = remotes:WaitForChild("LevelUpAvailable")
	local selectUpgrade = remotes:WaitForChild("SelectUpgrade")
	assert(available:IsA("RemoteEvent") and selectUpgrade:IsA("RemoteEvent"), "Progression remotes must be RemoteEvents")
	if started then
		return
	end
	started = true
	availableRemote = available
	table.insert(connections, selectUpgrade.OnServerEvent:Connect(SelectUpgrade))
	-- Late subscribers request the same pending offer, never a fresh reroll.
	table.insert(connections, available.OnServerEvent:Connect(function(player: Player)
		if not PlayerStateService.GetState(player) or player.Parent ~= Players then
			return
		end
		local record = GetChoices(player)
		local now = os.clock()
		if now < record.NextSyncAt then
			return
		end
		record.NextSyncAt = now + UpgradeConfig.SyncInterval
		EnsureOffer(player, record)
		SendOffer(player)
	end))
	table.insert(connections, Players.PlayerAdded:Connect(function(player: Player)
		GetChoices(player)
		ObserveLevel(player)
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		choices[player] = nil
	end))
	for _, player in Players:GetPlayers() do
		GetChoices(player)
		ObserveLevel(player)
	end
end

function ProgressionService.Destroy()
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(choices)
	availableRemote = nil
end

return ProgressionService
