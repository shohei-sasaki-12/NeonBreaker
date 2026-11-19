--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Attacks = require(script.Parent:WaitForChild("EnemyAttacks"))

type Shot = {
	Part: Part, Position: Vector3, Direction: Vector3, Speed: number, Remaining: number,
	Damage: number, ApplyDamage: Attacks.DamagePlayer, Params: RaycastParams, LastUpdate: number,
	Owner: Model?,
}
local shots: { [Part]: Shot } = {}
local EnemyProjectiles = {}

function EnemyProjectiles.Fire(origin: Vector3, direction: Vector3, speed: number, range: number, damage: number, applyDamage: Attacks.DamagePlayer, owner: Model?)
	local container = Workspace:FindFirstChild("ProjectileContainer")
	if not container or direction.Magnitude == 0 then return end
	local part = Attacks.MakeVisual("EnemyProjectile", Color3.fromRGB(255, 120, 55), Vector3.one * 0.55)
	part.Shape = Enum.PartType.Ball
	part.Position = origin
	local params = Attacks.RaycastParams(nil)
	params.RespectCanCollide = false -- Player hitboxes need only be queryable.
	shots[part] = {
		Part = part, Position = origin, Direction = direction.Unit, Speed = speed, Remaining = range,
		Damage = damage, ApplyDamage = applyDamage, Params = params, LastUpdate = os.clock(), Owner = owner,
	}
	part.Parent = container
end

function EnemyProjectiles.ClearOwner(owner: Model)
	for part, shot in shots do
		if shot.Owner == owner then
			shots[part] = nil
			part:Destroy()
		end
	end
end

function EnemyProjectiles.Update(now: number)
	for part, shot in shots do
		local distance = math.min(shot.Speed * math.max(0, now - shot.LastUpdate), shot.Remaining)
		if not part.Parent then shots[part] = nil; continue end
		if distance <= 0 then continue end
		shot.LastUpdate = now
		local displacement = shot.Direction * distance
		local hit = Workspace:Raycast(shot.Position, displacement, shot.Params)
		shot.Remaining -= distance
		if hit or shot.Remaining <= 0 then
			shots[part] = nil
			part:Destroy()
			if hit then
				local ancestor: Instance? = hit.Instance
				while ancestor and ancestor ~= Workspace do
					if ancestor:IsA("Model") then
						local player = Players:GetPlayerFromCharacter(ancestor)
						if player then
							shot.ApplyDamage(player, shot.Damage)
							break
						end
					end
					ancestor = ancestor.Parent
				end
			end
		else
			shot.Position += displacement
			part.Position = shot.Position
		end
	end
end

function EnemyProjectiles.Clear()
	for part in shots do part:Destroy() end
	table.clear(shots)
end

return EnemyProjectiles
