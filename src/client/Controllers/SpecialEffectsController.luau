--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GrenadeConfig"))
local EMPConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EMPConfig"))
local TurretConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("TurretConfig"))

local SpecialEffectsController = {}
local connection: RBXScriptConnection? = nil
local container: Folder? = nil
local started = false

local function OnEffect(effect)
	local folder = container
	if not folder then return end
	if effect.SpecialId == "Turret" and effect.Event == "Fired" then
		local offset = effect.Position - effect.Origin
		if offset.Magnitude <= 0 then return end
		local tracer = Instance.new("Part")
		tracer.Name = "TurretTracer"
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanTouch = false
		tracer.CanQuery = false
		tracer.CastShadow = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = TurretConfig.TracerColor
		tracer.Size = Vector3.new(TurretConfig.TracerThickness, TurretConfig.TracerThickness, offset.Magnitude)
		tracer.CFrame = CFrame.lookAt((effect.Origin + effect.Position) / 2, effect.Position)
		tracer.Parent = folder
		Debris:AddItem(tracer, TurretConfig.TracerDuration)
		return
	end
	local effectConfig
	if effect.SpecialId == "Grenade" and effect.Event == "Exploded" then
		effectConfig = Config
	elseif effect.SpecialId == "EMPPulse" and effect.Event == "Pulsed" then
		effectConfig = EMPConfig
	else
		return
	end
	local flash = Instance.new("Part")
	flash.Name = if effect.SpecialId == "Grenade" then "GrenadeExplosion" else "EMPPulseEffect"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = effectConfig.ExplosionColor
	flash.Size = Vector3.one
	flash.Position = effect.Position
	flash.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = effectConfig.ExplosionColor
	light.Brightness = effectConfig.ExplosionBrightness
	light.Range = effect.Radius * 2
	light.Parent = flash
	local info = TweenInfo.new(effectConfig.ExplosionDuration)
	TweenService:Create(flash, info, { Size = Vector3.one * effect.Radius * 2, Transparency = 1 }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	Debris:AddItem(flash, effectConfig.EffectLifetime)
end

function SpecialEffectsController.Init()
	if started then return end
	assert(RunService:IsClient(), "SpecialEffectsController must run on the client")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects"):WaitForChild("PlaySpecialEffect")
	assert(remote:IsA("RemoteEvent"), "PlaySpecialEffect must be a RemoteEvent")
	if started then return end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "LocalSpecialEffects"
	folder.Parent = Workspace
	container = folder
	connection = remote.OnClientEvent:Connect(OnEffect)
end

function SpecialEffectsController.Destroy()
	if not started then return end
	started = false
	if connection then connection:Disconnect() end
	connection = nil
	if container then container:Destroy() end
	container = nil
end

return SpecialEffectsController
