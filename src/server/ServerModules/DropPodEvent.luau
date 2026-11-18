--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StageConfig")).DropPod

export type State = "Pending" | "Warning" | "Landed" | "Unavailable"
export type Controller = { Update: (number) -> State, Reset: () -> () }
local DropPodEvent = {}

local function FindSite(spawnPoints: Folder): Vector3?
	for _, point in spawnPoints:GetChildren() do
		if point:IsA("BasePart") and point:GetAttribute("DropPod") == true
			and point:GetAttribute("BossOnly") ~= true then
			return point.Position
		end
	end

	local excluded: { Instance } = { spawnPoints }
	for _, name in { "EnemyContainer", "ProjectileContainer", "EffectContainer" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then table.insert(excluded, folder) end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then table.insert(excluded, character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	params.RespectCanCollide = true

	for _, site in Config.FallbackSites do
		local result = Workspace:Raycast(site + Vector3.new(0, Config.ProbeHeight, 0),
			Vector3.new(0, -Config.ProbeDepth, 0), params)
		if result then return result.Position end
	end
	return nil
end

local function MakePart(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

function DropPodEvent.new(spawnPoints: Folder, effects: Folder): Controller
	local state: State = "Pending"
	local warningAt = 0
	local site: Vector3? = nil
	local pod: Part? = nil
	local warning: Part? = nil
	local spawnPoint: Part? = nil

	local function Reset()
		if spawnPoint then spawnPoint:Destroy() end
		if warning then warning:Destroy() end
		if pod then pod:Destroy() end
		spawnPoint, warning, pod, site = nil, nil, nil, nil
		state = "Pending"
	end

	local function Update(elapsed: number): State
		if state == "Pending" and elapsed >= Config.StartAt then
			local landing = FindSite(spawnPoints)
			if not landing then
				warn("[DropPodEvent] No landing site. Add a DropPod marker or configure a fallback floor.")
				state = "Unavailable"
				return state
			end
			site = landing
			warningAt = elapsed
			state = "Warning"
			local marker = MakePart("DropPodWarning")
			marker.Size = Vector3.new(Config.Size.X * 1.5, 0.12, Config.Size.Z * 1.5)
			marker.Position = landing + Vector3.new(0, 0.12, 0)
			marker.Material = Enum.Material.Neon
			marker.Color = Color3.fromRGB(255, 97, 48)
			marker.Transparency = 0.35
			marker.Parent = effects
			warning = marker

			local transport = MakePart("DropPod")
			transport.Size = Config.Size
			transport.Material = Enum.Material.Metal
			transport.Color = Color3.fromRGB(115, 61, 55)
			transport.Parent = effects
			pod = transport
		end

		local transport, landing = pod, site
		if state == "Warning" and transport and landing then
			local progress = math.clamp((elapsed - warningAt) / Config.WarningDuration, 0, 1)
			transport.Position = landing + Vector3.new(0, Config.Size.Y / 2 + Config.FallHeight * (1 - progress), 0)
			if progress >= 1 then
				if warning then warning:Destroy(); warning = nil end
				local point = MakePart("DropPodSpawn")
				point.Size = Vector3.one
				point.Position = landing
				point.Transparency = 1
				point:SetAttribute("Enabled", true)
				point:SetAttribute("DropPod", true)
				point:SetAttribute("DropPodActive", true)
				point.Parent = spawnPoints
				spawnPoint = point
				state = "Landed"
			end
		end
		return state
	end

	return { Update = Update, Reset = Reset }
end

return DropPodEvent
