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
	IsReloading: boolean,
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
local started = false
local fireHeld = false
local ammo = config.MagazineSize
local reloadEndsAt: number? = nil
local nextShotAt = 0
local shotId = 0 -- Monotonic across respawns and Init/Destroy cycles.

function WeaponController.GetState(): WeaponState
	-- Return a snapshot; callers cannot mutate the controller's state.
	return table.freeze({
		WeaponId = config.WeaponId,
		Ammo = ammo,
		MagazineSize = config.MagazineSize,
		IsReloading = reloadEndsAt ~= nil,
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
	if reloadEndsAt ~= nil then
		reloadEndsAt = nil
		NotifyState()
	end
end

local function ResetWeapon()
	fireHeld = false
	reloadEndsAt = nil
	ammo = config.MagazineSize
	nextShotAt = 0
	NotifyState()
end

local function StartReload(now: number)
	if not started or not IsAlive() or reloadEndsAt ~= nil or ammo >= config.MagazineSize then
		return
	end
	-- Local prediction only. Server-authoritative ammo/reload is a later step.
	reloadEndsAt = now + config.ReloadTime
	NotifyState()
end

local function TryFire(now: number)
	if not started or not fireHeld or reloadEndsAt ~= nil or not IsAlive() then
		return
	end
	if ammo <= 0 then
		StartReload(now)
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
	nextShotAt = now + config.FireInterval
	ammo -= 1
	shotId += 1
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
	local deadline = reloadEndsAt
	if deadline ~= nil and now >= deadline then
		reloadEndsAt = nil
		ammo = config.MagazineSize
		NotifyState()
	end
	TryFire(now)
end

function WeaponController.Init()
	if started then
		return
	end
	assert(RunService:IsClient(), "WeaponController must run on the client")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat"):WaitForChild("FireWeapon")
	assert(remote:IsA("RemoteEvent"), "Combat.FireWeapon must be a RemoteEvent")
	-- WaitForChild can yield; guard against simultaneous Init calls.
	if started then
		return
	end
	fireRemote = remote
	started = true
	ResetWeapon()
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
	table.insert(connections, InputController.Reload:Connect(function()
		StartReload(os.clock())
	end))
	table.insert(connections, Players.LocalPlayer.CharacterRemoving:Connect(CancelActions))
	table.insert(connections, Players.LocalPlayer.CharacterAdded:Connect(ResetWeapon))
	table.insert(connections, RunService.Heartbeat:Connect(Update))
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
	fireRemote = nil
	-- Keep notification objects stable for a later Init().
end

return WeaponController
