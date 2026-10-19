--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local InputController = require(script.Parent:WaitForChild("InputController"))
local LevelUpView = require(script.Parent:WaitForChild("LevelUpView"))

local LevelUpController = {}
local started = false
local connections: { RBXScriptConnection } = {}
local view: LevelUpView.View? = nil
local current: LevelUpView.Offer? = nil
local busy = false

function LevelUpController.Init()
	if started then return end
	assert(RunService:IsClient(), "LevelUpController must run on the client")
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("LevelUpUI")
	assert(gui:IsA("ScreenGui"), "LevelUpUI must be a ScreenGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Progression")
	local available = remotes:WaitForChild("LevelUpAvailable") :: RemoteEvent
	local selectUpgrade = remotes:WaitForChild("SelectUpgrade") :: RemoteEvent
	started = true
	local elapsed = 0
	local received = false
	local localView = LevelUpView.Create(gui, function(id: string)
		local offer = current
		if busy or not offer or not table.find(offer.Candidates, id) then return end
		busy = true
		elapsed = 0
		if view then view.SetBusy(true) end
		selectUpgrade:FireServer(offer.OfferId, id)
	end)
	view = localView
	table.insert(connections, available.OnClientEvent:Connect(function(offer: LevelUpView.Offer)
		received = true
		elapsed = 0
		busy = false
		if offer.OfferId == 0 or #offer.Candidates == 0 then
			current = nil
			localView.Hide()
			InputController.SetUIBlocked(false)
		else
			current = offer
			InputController.SetUIBlocked(true)
			localView.Show(offer)
		end
	end))
	-- Recover a missed initial notification or selection response without rerolling.
	table.insert(connections, RunService.Heartbeat:Connect(function(dt: number)
		if received and not busy then return end
		elapsed += dt
		if elapsed >= 2 then
			elapsed = 0
			available:FireServer()
		end
	end))
	available:FireServer()
end

function LevelUpController.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	if view then view.Destroy() end
	view = nil
	current = nil
	busy = false
	InputController.SetUIBlocked(false)
end

return LevelUpController
