--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GrenadeConfig"))

local SpecialEffectsController = {}
local connection: RBXScriptConnection? = nil
local container: Folder? = nil
local started = false

local function OnEffect(effect)
	local folder = container
	if not folder or effect.SpecialId ~= "Grenade" or effect.Event ~= "Exploded" then return end
	local flash = Instance.new("Part")
	flash.Name = "GrenadeExplosion"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Config.ExplosionColor
	flash.Size = Vector3.one
	flash.Position = effect.Position
	flash.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = Config.ExplosionColor
	light.Brightness = Config.ExplosionBrightness
	light.Range = effect.Radius * 2
	light.Parent = flash
	local info = TweenInfo.new(Config.ExplosionDuration)
	TweenService:Create(flash, info, { Size = Vector3.one * effect.Radius * 2, Transparency = 1 }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	Debris:AddItem(flash, Config.EffectLifetime)
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
