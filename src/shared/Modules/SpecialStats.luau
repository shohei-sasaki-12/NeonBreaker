--!strict

local Config = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
local SpecialConfig = require(Config:WaitForChild("SpecialEquipmentConfig"))
local GrenadeConfig = require(Config:WaitForChild("GrenadeConfig"))
local UpgradeConfig = require(Config:WaitForChild("UpgradeConfig"))

export type GrenadeStats = { Damage: number, BlastRadius: number, Cooldown: number, Count: number }
local SpecialStats = {}

-- Percentages add against base values. SpecialLevel is equipment ownership, not an upgrade rank.
function SpecialStats.GetGrenadeStats(upgrades: { [string]: number }): GrenadeStats
	local effects: { [string]: number } = {}
	for id, level in upgrades do
		local definition = UpgradeConfig.GetUpgradeConfig(id)
		if definition and definition.Enabled ~= false and definition.Category == "Special"
			and definition.SpecialRequirement == "Grenade" then
			local value = math.clamp(level, 0, definition.MaxLevel) * definition.EffectValue
			effects[definition.EffectType] = (effects[definition.EffectType] or 0) + value
		end
	end
	local base = SpecialConfig.GetSpecialConfig("Grenade")
	assert(base, "Grenade configuration is missing")
	return table.freeze({
		Damage = GrenadeConfig.Damage * (1 + (effects.SpecialDamageMultiplier or 0)),
		BlastRadius = GrenadeConfig.BlastRadius * (1 + (effects.SpecialRadiusMultiplier or 0)),
		Cooldown = math.max(0, base.Cooldown * (1 - (effects.SpecialCooldownReduction or 0))),
		Count = math.max(1, math.round(1 + (effects.SpecialCountBonus or 0))),
	})
end

return table.freeze(SpecialStats)
