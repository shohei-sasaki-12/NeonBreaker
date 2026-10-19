--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local WeaponConfig = require(ConfigFolder:WaitForChild("WeaponConfig"))
local UpgradeConfig = require(ConfigFolder:WaitForChild("UpgradeConfig"))

local WeaponStats = {}

local function Effect(upgrades: { [string]: number }, id: string): number
	local definition = UpgradeConfig.GetUpgradeConfig(id)
	assert(definition, "Unknown upgrade")
	return math.clamp(upgrades[id] or 0, 0, definition.MaxLevel) * definition.EffectValue
end

function WeaponStats.GetWeaponConfig(weaponId: string, upgrades: { [string]: number }): WeaponConfig.WeaponDefinition?
	local base = WeaponConfig.GetWeaponConfig(weaponId)
	if not base then
		return nil
	end
	-- Additive percentages of base stats; never mutate the shared base definition.
	local result = table.clone(base)
	result.Damage = base.Damage * (1 + Effect(upgrades, "DamageUp"))
	result.FireInterval = base.FireInterval * (1 - Effect(upgrades, "FireRateUp"))
	result.MagazineSize = math.round(base.MagazineSize * (1 + Effect(upgrades, "MagazineUp")))
	return table.freeze(result)
end

return table.freeze(WeaponStats)
