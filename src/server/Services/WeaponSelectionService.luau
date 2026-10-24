--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WeaponSelectionConfig"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local StageService = require(script.Parent:WaitForChild("StageService"))

local WeaponSelectionService = {}
local started = false
local connections: { RBXScriptConnection } = {}
local nextRequestAt: { [Player]: number } = {}
local nextSnapshotAt: { [Player]: number } = {}

function WeaponSelectionService.SelectWeapon(player: Player, weaponId: any): (boolean, string)
	assert(RunService:IsServer(), "Weapon selection must run on the server")
	if not started or player.Parent ~= Players or not PlayerStateService.GetState(player) then
		return false, "NotReady"
	end
	if StageService.GetState().State ~= "Waiting" then return false, "Locked" end
	if not PlayerStateService.TrySelectWeapon(player, weaponId) then return false, "InvalidWeapon" end
	return true, "Selected"
end

function WeaponSelectionService.Init()
	if started then return end
	assert(RunService:IsServer(), "WeaponSelectionService must run on the server")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby"):WaitForChild("SelectWeapon")
	assert(remote:IsA("RemoteEvent"), "SelectWeapon must be a RemoteEvent")
	if started then return end
	started = true
	table.insert(connections, remote.OnServerEvent:Connect(function(player: Player, weaponId: any)
		if player.Parent ~= Players then return end
		local success, reason = false, "Snapshot"
		local now = os.clock()
		local throttle = if weaponId == nil then nextSnapshotAt else nextRequestAt
		if now < (throttle[player] or 0) then
			-- Silently drop spam; the client can request a fresh snapshot later.
			return
		end
		throttle[player] = now + Config.RequestInterval
		-- No argument requests only a snapshot; it never confirms the default weapon.
		if weaponId ~= nil then success, reason = WeaponSelectionService.SelectWeapon(player, weaponId) end
		local state = PlayerStateService.GetState(player)
		if state then
			remote:FireClient(player, {
				Success = success, Reason = reason, CurrentWeaponId = state.CurrentWeaponId,
				HasSelectedWeapon = state.HasSelectedWeapon, StageState = StageService.GetState().State,
			})
		end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		nextRequestAt[player] = nil
		nextSnapshotAt[player] = nil
	end))
end

function WeaponSelectionService.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(nextRequestAt)
	table.clear(nextSnapshotAt)
end

return WeaponSelectionService
