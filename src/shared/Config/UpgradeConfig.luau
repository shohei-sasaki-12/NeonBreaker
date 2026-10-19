--!strict

export type UpgradeDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	Category: string,
	MaxLevel: number,
	Weight: number,
	Requirements: { string },
	ExcludedWeapons: { string },
	EffectType: string,
	EffectValue: number,
}

local definitions: { [string]: UpgradeDefinition } = {
	DamageUp = {
		Id = "DamageUp", DisplayName = "Damage Up", Description = "Damage +10% per level",
		Category = "Weapon", MaxLevel = 5, Weight = 1,
		Requirements = {}, ExcludedWeapons = {}, EffectType = "DamageMultiplier", EffectValue = 0.10,
	},
	FireRateUp = {
		Id = "FireRateUp", DisplayName = "Fire Rate Up", Description = "Fire interval -6% per level",
		Category = "Weapon", MaxLevel = 5, Weight = 1,
		Requirements = {}, ExcludedWeapons = {}, EffectType = "FireIntervalReduction", EffectValue = 0.06,
	},
	MagazineUp = {
		Id = "MagazineUp", DisplayName = "Magazine Up", Description = "Magazine size +15% per level",
		Category = "Weapon", MaxLevel = 5, Weight = 1,
		Requirements = {}, ExcludedWeapons = {}, EffectType = "MagazineMultiplier", EffectValue = 0.15,
	},
}
local ids = table.freeze({ "DamageUp", "FireRateUp", "MagazineUp" })
for _, definition in definitions do
	table.freeze(definition.Requirements)
	table.freeze(definition.ExcludedWeapons)
	table.freeze(definition)
end
table.freeze(definitions)

local UpgradeConfig = { ChoiceCount = 3, SelectInterval = 0.1, SyncInterval = 0.5 }

function UpgradeConfig.GetUpgradeConfig(upgradeId: string): UpgradeDefinition?
	return definitions[upgradeId]
end

function UpgradeConfig.GetUpgradeIds(): { string }
	return table.clone(ids)
end

return table.freeze(UpgradeConfig)
