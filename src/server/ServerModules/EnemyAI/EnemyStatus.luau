--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EMPConfig"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyConfig"))
local StatusConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StatusEffectConfig"))

export type Controller = {
	ApplyEMP: () -> boolean,
	Update: (slowRate: number?, frozen: boolean?) -> boolean, -- true means AI must skip movement and attacks.
	Destroy: () -> (),
}

local EnemyStatus = {}

function EnemyStatus.IsBoss(model: Model, config: EnemyConfig.EnemyDefinition): boolean
	return config.IsBoss == true or CollectionService:HasTag(model, "Boss")
end

function EnemyStatus.new(model: Model, humanoid: Humanoid, config: EnemyConfig.EnemyDefinition): Controller
	local stunnedUntil = 0
	local slowedUntil = 0
	local active = true
	local movementChanged = false
	local commonSlowRate = 0
	local cryoFrozen = false
	local function Update(slowRate: number?, frozen: boolean?): boolean
		if not active then return false end
		if slowRate ~= nil then commonSlowRate = slowRate end
		if frozen ~= nil then cryoFrozen = frozen end
		local now = Workspace:GetServerTimeNow()
		local isBoss = EnemyStatus.IsBoss(model, config)
		local stunned = not isBoss and now < stunnedUntil
		local immobilized = stunned or (cryoFrozen and not isBoss)
		local slowed = now < slowedUntil
		local multiplier = math.min(1 - commonSlowRate, if slowed then Config.BossSpeedMultiplier else 1)
		if isBoss then multiplier = math.max(StatusConfig.BossMinimumSpeedMultiplier, multiplier) end
		if immobilized or multiplier < 1 then
			humanoid.WalkSpeed = if immobilized then 0 else config.MoveSpeed * multiplier
			movementChanged = true
		elseif movementChanged then
			humanoid.WalkSpeed = config.MoveSpeed
			movementChanged = false
		end
		model:SetAttribute("EMPStunnedUntil", if stunned then stunnedUntil else 0)
		model:SetAttribute("EMPSlowedUntil", if slowed then slowedUntil else 0)
		if immobilized then
			local root = model.PrimaryPart
			if root then humanoid:MoveTo(root.Position) end
		end
		return immobilized
	end
	return {
		ApplyEMP = function(): boolean
			if not active or humanoid.Health <= 0 or config.IsMechanical ~= true then return false end
			local now = Workspace:GetServerTimeNow()
			if EnemyStatus.IsBoss(model, config) then
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
