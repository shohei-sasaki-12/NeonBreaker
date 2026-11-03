--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EMPConfig"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyConfig"))

export type Controller = {
	ApplyEMP: () -> boolean,
	Update: () -> boolean, -- true means AI must skip movement and attacks.
	Destroy: () -> (),
}

local EnemyStatus = {}

function EnemyStatus.new(model: Model, humanoid: Humanoid, config: EnemyConfig.EnemyDefinition): Controller
	local stunnedUntil = 0
	local slowedUntil = 0
	local active = true
	local movementChanged = false
	local function IsBoss(): boolean
		-- Boss tags also protect future boss rigs whose config has not declared IsBoss yet.
		return config.IsBoss == true or CollectionService:HasTag(model, "Boss")
	end
	local function Update(): boolean
		if not active then return false end
		local now = Workspace:GetServerTimeNow()
		local stunned = not IsBoss() and now < stunnedUntil
		local slowed = now < slowedUntil
		if stunned or slowed then
			humanoid.WalkSpeed = if stunned then 0 else config.MoveSpeed * Config.BossSpeedMultiplier
			movementChanged = true
		elseif movementChanged then
			humanoid.WalkSpeed = config.MoveSpeed
			movementChanged = false
		end
		model:SetAttribute("EMPStunnedUntil", if stunned then stunnedUntil else 0)
		model:SetAttribute("EMPSlowedUntil", if slowed then slowedUntil else 0)
		if stunned then
			local root = model.PrimaryPart
			if root then humanoid:MoveTo(root.Position) end
		end
		return stunned
	end
	return {
		ApplyEMP = function(): boolean
			if not active or humanoid.Health <= 0 or config.IsMechanical ~= true then return false end
			local now = Workspace:GetServerTimeNow()
			if IsBoss() then
				slowedUntil = math.max(slowedUntil, now + Config.BossSlowDuration)
			else
				-- Refresh from this hit, rather than adding durations for simultaneous pulses.
				stunnedUntil = math.max(stunnedUntil, now + Config.StunDuration)
			end
			Update()
			return true
		end,
		Update = Update,
		Destroy = function()
			if not active then return end
			active = false
			if movementChanged then humanoid.WalkSpeed = config.MoveSpeed end
			model:SetAttribute("EMPStunnedUntil", nil)
			model:SetAttribute("EMPSlowedUntil", nil)
		end,
	}
end

return EnemyStatus
