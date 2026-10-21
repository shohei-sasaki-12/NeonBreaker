--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WeaponEffectsConfig"))
local WeaponController = require(script.Parent:WaitForChild("WeaponController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))

type PendingShot = { Muzzle: Vector3, ExpiresAt: number }
type ResolvedShot = { WeaponId: string, ShotId: number, Character: Model, Origin: Vector3, EndPositions: { Vector3 } }
local WeaponEffectsController = {}
local connections: { RBXScriptConnection } = {}
local pending: { [number]: PendingShot } = {}
local container: Folder? = nil
local started = false

local function VisualPart(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

local function OnShot(shot: WeaponController.ShotInfo)
	if shot.WeaponId ~= "Shotgun" then return end
	local camera = Workspace.CurrentCamera
	local folder = container
	if not camera or not folder then return end
	local effect = Config.Shotgun
	-- Until a weapon model exists, show a camera-relative muzzle proxy.
	local muzzle = camera.CFrame:PointToWorldSpace(effect.MuzzleOffset)
	pending[shot.ShotId] = { Muzzle = muzzle, ExpiresAt = os.clock() + effect.PendingLifetime }
	local sound = Instance.new("Sound")
	sound.Name = "ShotgunFire"
	sound.SoundId = effect.FireSoundId
	sound.Volume = effect.SoundVolume
	sound.PlaybackSpeed = effect.SoundPlaybackSpeed
	sound.Parent = folder
	sound:Play()
	Debris:AddItem(sound, effect.SoundLifetime)
	CameraController.AddRecoil(effect.RecoilDegrees)
	local flash = VisualPart("MuzzleFlash", effect.Color)
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * effect.FlashSize
	flash.Position = muzzle
	local light = Instance.new("PointLight")
	light.Color = effect.Color
	light.Brightness = effect.FlashBrightness
	light.Range = effect.FlashRange
	light.Parent = flash
	flash.Parent = folder
	Debris:AddItem(flash, effect.FlashDuration)
end

local function OnResolved(shot: ResolvedShot)
	local folder = container
	if not folder or shot.WeaponId ~= "Shotgun" or shot.Character ~= Players.LocalPlayer.Character then return end
	local predicted = pending[shot.ShotId]
	pending[shot.ShotId] = nil
	local origin = if predicted then predicted.Muzzle else shot.Origin
	local effect = Config.Shotgun
	-- Endpoints come only from the server's accepted pellet raycasts.
	for _, endpoint in shot.EndPositions do
		local length = (endpoint - origin).Magnitude
		if length <= 0 then continue end
		local tracer = VisualPart("ShotgunTracer", effect.Color)
		tracer.Size = Vector3.new(effect.TracerWidth, effect.TracerWidth, length)
		tracer.CFrame = CFrame.lookAt((origin + endpoint) / 2, endpoint)
		tracer.Parent = folder
		Debris:AddItem(tracer, effect.TracerDuration)
	end
end

function WeaponEffectsController.Init()
	if started then return end
	assert(RunService:IsClient(), "WeaponEffectsController must run on the client")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat"):WaitForChild("WeaponShotResolved")
	assert(remote:IsA("RemoteEvent"), "WeaponShotResolved must be a RemoteEvent")
	if started then return end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "LocalWeaponEffects"
	folder.Parent = Workspace
	container = folder
	table.insert(connections, WeaponController.ShotFired:Connect(OnShot))
	table.insert(connections, remote.OnClientEvent:Connect(OnResolved))
	table.insert(connections, Players.LocalPlayer.CharacterRemoving:Connect(function()
		table.clear(pending)
		folder:ClearAllChildren()
	end))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for id, shot in pending do
			if now >= shot.ExpiresAt then pending[id] = nil end
		end
	end))
end

function WeaponEffectsController.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(pending)
	if container then container:Destroy() end
	container = nil
end

return WeaponEffectsController
