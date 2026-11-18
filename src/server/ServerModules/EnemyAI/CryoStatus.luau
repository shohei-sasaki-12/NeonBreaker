--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local EnemyStatus = require(script.Parent:WaitForChild("EnemyStatus"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CryoConfig"))
local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnemyConfig"))

export type Snapshot = {
	CoolingValue: number, SlowRate: number, SlowUntil: number,
	IsFrozen: boolean, FreezeUntil: number, FreezeImmuneUntil: number,
}
export type Controller = {
	AddCooling: (number) -> boolean,
	Update: () -> Snapshot,
	Destroy: () -> (),
}

local CryoStatus = {}

function CryoStatus.new(model: Model, config: EnemyConfig.EnemyDefinition): Controller
	local active = true
	local cooling = 0
	local lastHitAt = 0
	local updatedAt = Workspace:GetServerTimeNow()
	local slowRate = 0
	local slowUntil = 0
	local freezeUntil = 0
	local immuneUntil = 0
	local function IsBoss(): boolean
		return EnemyStatus.IsBoss(model, config)
	end
	local function Update(): Snapshot
		local now = Workspace:GetServerTimeNow()
		if active then
			local decayFrom = math.max(updatedAt, lastHitAt + Config.DecayDelay)
			cooling = math.max(0, cooling - math.max(0, now - decayFrom) * Config.DecayPerSecond)
			updatedAt = now
			if IsBoss() then freezeUntil = 0 end
			if now >= freezeUntil then freezeUntil = 0 end
			if now >= immuneUntil then immuneUntil = 0 end
			if now >= slowUntil then slowRate, slowUntil = 0, 0 end
		end
		local effectiveSlow = if IsBoss() then math.min(slowRate, Config.BossMaxSlowRate) else slowRate
		local snapshot: Snapshot = table.freeze({
			CoolingValue = cooling, SlowRate = effectiveSlow, SlowUntil = slowUntil,
			IsFrozen = freezeUntil > now and not IsBoss(), FreezeUntil = freezeUntil, FreezeImmuneUntil = immuneUntil,
		})
		if active then
			-- Mirrors only; authoritative values stay in this controller.
			model:SetAttribute("CoolingValue", cooling)
			model:SetAttribute("CryoSlowRate", effectiveSlow)
			model:SetAttribute("CryoSlowUntil", slowUntil)
			model:SetAttribute("CryoFreezeUntil", freezeUntil)
			model:SetAttribute("CryoFreezeImmuneUntil", immuneUntil)
		end
		return snapshot
	end
	return {
		AddCooling = function(level: number): boolean
			local definition = Config.GetLevelConfig(level)
			if not active or not definition then return false end
			local current = Update()
			if current.IsFrozen then return false end -- Hits cannot extend an active Freeze.
			local now = Workspace:GetServerTimeNow()
			cooling = math.min(Config.MaxCooling, cooling + definition.CoolingPerHit)
			lastHitAt = now
			if cooling >= Config.SlowThreshold then
				-- Overlapping hits refresh duration and keep the strongest current Slow.
				slowRate = math.max(slowRate, definition.SlowRate)
				slowUntil = now + Config.SlowDuration
			end
			if level == 3 and cooling >= Config.FreezeThreshold and now >= immuneUntil and not IsBoss() then
				cooling = 0
				freezeUntil = now + Config.FreezeDuration
				immuneUntil = freezeUntil + Config.FreezeImmunityDuration
			end
			Update()
			return true
		end,
		Update = Update,
		Destroy = function()
			active = false
			cooling, slowRate, slowUntil, freezeUntil, immuneUntil = 0, 0, 0, 0, 0
			for _, name in { "CoolingValue", "CryoSlowRate", "CryoSlowUntil", "CryoFreezeUntil", "CryoFreezeImmuneUntil" } do
				model:SetAttribute(name, nil)
			end
		end,
	}
end

return CryoStatus
