--!strict

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local EnemyAttacks = {}

export type DamagePlayer = (Player, number) -> boolean

function EnemyAttacks.RaycastParams(ignore: Instance?): RaycastParams
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	local exclusions: { Instance } = {}
	if ignore then table.insert(exclusions, ignore) end
	for _, name in { "EnemyContainer", "ProjectileContainer", "SpawnPoints" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then table.insert(exclusions, folder) end
	end
	params.FilterDescendantsInstances = exclusions
	params.FilterType = Enum.RaycastFilterType.Exclude
	return params
end

function EnemyAttacks.MakeVisual(name: string, color: Color3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	return part
end

function EnemyAttacks.ShowArea(position: Vector3, radius: number, lifetime: number, color: Color3): Part
	local ground = Workspace:Raycast(position, Vector3.new(0, -12, 0), EnemyAttacks.RaycastParams(nil))
	local center = if ground then ground.Position else position
	local part = EnemyAttacks.MakeVisual("EnemyAttackArea", color, Vector3.new(0.12, radius * 2, radius * 2))
	part.Shape = Enum.PartType.Cylinder
	part.Transparency = 0.45
	part.CFrame = CFrame.new(center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	part.Parent = Workspace
	Debris:AddItem(part, lifetime)
	return part
end

function EnemyAttacks.DamageArea(position: Vector3, radius: number, amount: number, damage: DamagePlayer)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local offset = root.Position - position
			if offset.Magnitude <= radius and (offset.Magnitude == 0
				or not Workspace:Raycast(position, offset, EnemyAttacks.RaycastParams(character))) then
				damage(player, amount)
			end
		end
	end
end

return EnemyAttacks
