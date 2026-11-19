--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("DashConfig"))
local StageService = require(script.Parent:WaitForChild("StageService"))
local Validation = require(script.Parent.Parent:WaitForChild("ServerModules"):WaitForChild("CombatValidation"))

local DashService = {}
type Dash = { Attachment: Attachment, Mover: LinearVelocity, EndsAt: number }
local active: { [Player]: Dash } = {}
local readyAt: { [Player]: number } = {}
local connections: { RBXScriptConnection } = {}

local function Stop(player: Player)
	local dash = active[player]
	if not dash then return end
	active[player] = nil
	dash.Mover:Destroy()
	dash.Attachment:Destroy()
end

local function OnDash(player: Player, direction: any)
	local now = Workspace:GetServerTimeNow()
	if active[player] or now < (readyAt[player] or 0) or not StageService.IsLivingParticipant(player)
		or not Validation.IsDirection(direction) or math.abs(direction.Y) > 0.01 then return end
	local root = Validation.GetLivingRoot(player, player.Character)
	if not root or root.Anchored then return end
	local horizontal = Vector3.new(direction.X, 0, direction.Z).Unit * Config.Speed
	readyAt[player] = now + Config.Cooldown

	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "DashVelocity"
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.xAxis
	mover.SecondaryTangentAxis = Vector3.zAxis
	mover.ForceLimitsEnabled = true
	mover.MaxForce = root.AssemblyMass * Config.ForcePerMass
	mover.PlaneVelocity = Vector2.new(horizontal.X, horizontal.Z)
	mover.Attachment0 = attachment
	active[player] = { Attachment = attachment, Mover = mover, EndsAt = now + Config.Duration }
	mover.Parent = root
end

function DashService.Init()
	if #connections > 0 then return end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat"):WaitForChild("Dash")
	assert(remote:IsA("RemoteEvent") and RunService:IsServer(), "Dash requires a server RemoteEvent")
	table.insert(connections, remote.OnServerEvent:Connect(OnDash))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for player, dash in active do
			if now >= dash.EndsAt or not StageService.IsLivingParticipant(player) or not dash.Mover.Parent then Stop(player) end
		end
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		Stop(player)
		readyAt[player] = nil
	end))
end

function DashService.Destroy()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for player in active do Stop(player) end
	table.clear(readyAt)
end

return DashService
