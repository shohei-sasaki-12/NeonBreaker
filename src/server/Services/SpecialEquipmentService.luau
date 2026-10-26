--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SpecialEquipmentConfig"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

export type SpecialHandler = (player: Player, level: number) -> ()
local SpecialEquipmentService = {}
local handlers: { [string]: SpecialHandler } = {}
local connections: { RBXScriptConnection } = {}
local nextRequestAt: { [Player]: number } = {}
local inUse: { [Player]: boolean } = {}
local started = false

-- Future equipment modules register their behavior here, without adding client authority.
function SpecialEquipmentService.RegisterSpecial(specialId: string, handler: SpecialHandler): boolean
	assert(RunService:IsServer(), "Special behavior must be registered on the server")
	if not Config.GetSpecialConfig(specialId) or typeof(handler) ~= "function" or handlers[specialId] then return false end
	handlers[specialId] = handler
	return true
end

function SpecialEquipmentService.UseSpecial(player: Player): (boolean, string)
	assert(RunService:IsServer(), "Special equipment must be used on the server")
	local state = PlayerStateService.GetState(player)
	if not started or player.Parent ~= Players or not state then return false, "NotReady" end
	if inUse[player] then return false, "Busy" end
	local id = state.CurrentSpecial
	if not id then return false, "NotEquipped" end
	local definition = Config.GetSpecialConfig(id)
	if not definition or state.SpecialLevel < 1 or state.SpecialLevel > definition.MaxLevel then return false, "InvalidEquipment" end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not character.Parent or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") then return false, "NotAlive" end
	if Workspace:GetServerTimeNow() < state.SpecialCooldown then return false, "Cooldown" end
	local handler = handlers[id]
	if not handler then return false, "NotImplemented" end
	-- Reserve before notifications/effects can re-enter. Failed callbacks retain cooldown.
	inUse[player] = true
	if not PlayerStateService.TryStartSpecialCooldown(player, id, state.SpecialLevel) then
		inUse[player] = nil
		return false, "StateChanged"
	end
	local ok, message = pcall(handler, player, state.SpecialLevel)
	inUse[player] = nil
	if not ok then
		warn("[SpecialEquipmentService] " .. id .. " failed: " .. tostring(message))
		return false, "ActivationFailed"
	end
	return true, "Used"
end

function SpecialEquipmentService.Init()
	if started then return end
	assert(RunService:IsServer(), "SpecialEquipmentService must run on the server")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat"):WaitForChild("UseSpecial")
	assert(remote:IsA("RemoteEvent"), "UseSpecial must be a RemoteEvent")
	if started then return end
	started = true
	table.insert(connections, remote.OnServerEvent:Connect(function(player: Player)
		if player.Parent ~= Players then return end
		local now = Workspace:GetServerTimeNow()
		if now < (nextRequestAt[player] or 0) then return end
		nextRequestAt[player] = now + Config.RequestInterval
		-- All supplied client arguments are ignored. Ownership and values come from PlayerState.
		local success, reason = SpecialEquipmentService.UseSpecial(player)
		local state = PlayerStateService.GetState(player)
		if state and player.Parent == Players then
			remote:FireClient(player, {
				Success = success, Reason = reason, CurrentSpecial = state.CurrentSpecial,
				SpecialLevel = state.SpecialLevel, SpecialCooldown = state.SpecialCooldown,
				RemainingCooldown = math.max(0, state.SpecialCooldown - Workspace:GetServerTimeNow()),
			})
		end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		nextRequestAt[player] = nil
		inUse[player] = nil
	end))
end

function SpecialEquipmentService.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(nextRequestAt)
	table.clear(inUse)
	table.clear(handlers)
end

return SpecialEquipmentService
