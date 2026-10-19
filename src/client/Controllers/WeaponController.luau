--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local InputController = require(script.Parent:WaitForChild("InputController"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WeaponConfig"))
local definition = WeaponConfig.GetWeaponConfig("AssaultRifle")
assert(definition, "AssaultRifle is missing from WeaponConfig")
local config: WeaponConfig.WeaponDefinition = definition

export type WeaponState = {
	WeaponId: string,
	Ammo: number,
	MagazineSize: number,
	FireInterval: number,
	Damage: number,
	IsReloading: boolean,
	Ready: boolean,
}

export type ShotInfo = {
	WeaponId: string,
	Origin: Vector3,
	Direction: Vector3,
	ShotId: number,
}

local stateChanged = Instance.new("BindableEvent")
local shotFired = Instance.new("BindableEvent")
local WeaponController = {
	StateChanged = stateChanged.Event, -- (state: WeaponState), for a future HUD.
	ShotFired = shotFired.Event, -- (shot: ShotInfo), for local sound and muzzle flash.
}
local connections: { RBXScriptConnection } = {}
local fireRemote: RemoteEvent? = nil
local reloadRemote: RemoteEvent? = nil
local stateRemote: RemoteEvent? = nil
local started = false
local ready = false
local fireHeld = false
local ammo = config.MagazineSize
local magazineSize = config.MagazineSize
local fireInterval = config.FireInterval
local damage = config.Damage
local isReloading = false
local pendingShots: { [number]: boolean } = {}
local pendingReloadId: number? = nil
local reloadId = 0
local latestRevision = 0
local nextShotAt = 0
local shotId = 0 -- Monotonic across respawns and Init/Destroy cycles.

function WeaponController.GetState(): WeaponState
	-- Return a snapshot; callers cannot mutate the controller's state.
	return table.freeze({
		WeaponId = config.WeaponId,
		Ammo = ammo,
		MagazineSize = magazineSize,
		FireInterval = fireInterval,
		Damage = damage,
		IsReloading = isReloading,
		Ready = ready,
	})
end

local function NotifyState()
	stateChanged:Fire(WeaponController.GetState())
end

local function IsAlive(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0
end

local function CancelActions()
	fireHeld = false
	pendingReloadId = nil
	if isReloading or ready then
		isReloading = false
		ready = false
		NotifyState()
	end
end

local function ResetWeapon()
	fireHeld = false
	isReloading = false
	ready = false
	pendingReloadId = nil
	table.clear(pendingShots)
	ammo = magazineSize
	nextShotAt = 0
	NotifyState()
	local remote = stateRemote
	if remote then
		remote:FireServer()
	end
end

local function StartReload()
	local remote = reloadRemote
	if not started or not ready or not remote or not IsAlive() or isReloading or ammo >= magazineSize then
		return
	end
	-- Predict the start only; ammunition is refilled by a server snapshot.
	reloadId += 1
	pendingReloadId = reloadId
	isReloading = true
	NotifyState()
	remote:FireServer(config.WeaponId, reloadId)
end

local function TryFire(now: number)
	if not started or not ready or not fireHeld or isReloading or not IsAlive() then
		return
	end
	if ammo <= 0 then
		StartReload()
		return
	end
	if now < nextShotAt then
		return
	end
	local camera = Workspace.CurrentCamera
	local remote = fireRemote
	if not camera or not remote then
		return
	end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local direction = ray.Direction.Unit
	-- No catch-up burst after a slow frame, and clicking cannot bypass cooldown.
	nextShotAt = now + fireInterval
	ammo -= 1
	shotId += 1
	pendingShots[shotId] = true
	remote:FireServer(config.WeaponId, ray.Origin, direction, shotId)
	local shot: ShotInfo = {
		WeaponId = config.WeaponId,
		Origin = ray.Origin,
		Direction = direction,
		ShotId = shotId,
	}
	shotFired:Fire(table.freeze(shot))
	NotifyState()
end

local function Update()
	if not IsAlive() then
		CancelActions()
		return
	end
	local now = os.clock()
	TryFire(now)
end

type ServerState = {
	Character: Model?,
	WeaponId: string,
	Ammo: number,
	MagazineSize: number,
	FireInterval: number,
	Damage: number,
	IsReloading: boolean,
	AckShotId: number,
	AckReloadId: number,
	Revision: number,
}

local function OnServerState(state: ServerState)
	if not started or state.Character ~= Players.LocalPlayer.Character or state.Character == nil
		or state.WeaponId ~= config.WeaponId or state.Revision <= latestRevision then
		return
	end
	latestRevision = state.Revision
	magazineSize = state.MagazineSize
	fireInterval = state.FireInterval
	damage = state.Damage
	local unacknowledged = 0
	for id in pendingShots do
		if id <= state.AckShotId then
			pendingShots[id] = nil
		else
			unacknowledged += 1
		end
	end
	-- Preserve predictions made after this snapshot's acknowledgement.
	ammo = math.max(0, state.Ammo - unacknowledged)
	if pendingReloadId ~= nil and state.AckReloadId >= pendingReloadId then
		pendingReloadId = nil
	end
	isReloading = state.IsReloading or pendingReloadId ~= nil
	ready = true
	NotifyState()
end

function WeaponController.Init()
	if started then
		return
	end
	assert(RunService:IsClient(), "WeaponController must run on the client")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat")
	local remote = remotes:WaitForChild("FireWeapon")
	local reload = remotes:WaitForChild("ReloadWeapon")
	local snapshot = remotes:WaitForChild("WeaponStateChanged")
	assert(remote:IsA("RemoteEvent") and reload:IsA("RemoteEvent") and snapshot:IsA("RemoteEvent"), "Combat remotes must be RemoteEvents")
	-- WaitForChild can yield; guard against simultaneous Init calls.
	if started then
		return
	end
	fireRemote = remote
	reloadRemote = reload
	stateRemote = snapshot
	started = true
	latestRevision = 0
	table.insert(connections, snapshot.OnClientEvent:Connect(OnServerState))
	table.insert(connections, InputController.FirePressed:Connect(function()
		if not IsAlive() then
			return
		end
		fireHeld = true
		TryFire(os.clock())
	end))
	table.insert(connections, InputController.FireReleased:Connect(function()
		fireHeld = false
	end))
	table.insert(connections, InputController.Reload:Connect(StartReload))
	table.insert(connections, Players.LocalPlayer.CharacterRemoving:Connect(CancelActions))
	table.insert(connections, Players.LocalPlayer.CharacterAdded:Connect(ResetWeapon))
	table.insert(connections, RunService.Heartbeat:Connect(Update))
	ResetWeapon()
end

function WeaponController.Destroy()
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	CancelActions()
	table.clear(pendingShots)
	fireRemote = nil
	reloadRemote = nil
	stateRemote = nil
	-- Keep notification objects stable for a later Init().
end

return WeaponController
