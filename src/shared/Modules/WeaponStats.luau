--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local WeaponConfig = require(ConfigFolder:WaitForChild("WeaponConfig"))
local UpgradeConfig = require(ConfigFolder:WaitForChild("UpgradeConfig"))

local WeaponStats = {}

function WeaponStats.GetWeaponConfig(weaponId: string, upgrades: { [string]: number }): WeaponConfig.WeaponDefinition?
	local base = WeaponConfig.GetWeaponConfig(weaponId)
	if not base then
		return nil
	end
	local effects: { [string]: number } = {}
	for id, level in upgrades do
		local definition = UpgradeConfig.GetUpgradeConfig(id)
		if definition and UpgradeConfig.IsWeaponCompatible(id, weaponId) then
			local value = math.clamp(level, 0, definition.MaxLevel) * definition.EffectValue
			effects[definition.EffectType] = (effects[definition.EffectType] or 0) + value
		end
	end
	-- Additive percentages of base stats; never mutate the shared base definition.
	local result = table.clone(base)
	result.Damage = base.Damage * (1 + (effects.DamageMultiplier or 0))
	result.FireInterval = base.FireInterval * (1 - (effects.FireIntervalReduction or 0))
	result.MagazineSize = math.round(base.MagazineSize * (1 + (effects.MagazineMultiplier or 0)))
	if base.PelletCount then result.PelletCount = math.round(base.PelletCount + (effects.PelletCountBonus or 0)) end
	if base.Spread then result.Spread = math.max(0, base.Spread * (1 - (effects.SpreadReduction or 0))) end
	result.CriticalChance = math.clamp(base.CriticalChance + (effects.CriticalChanceBonus or 0), 0, 1)
	return table.freeze(result)
end

return table.freeze(WeaponStats)
