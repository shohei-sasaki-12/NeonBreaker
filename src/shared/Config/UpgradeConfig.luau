--!strict

local WeaponConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WeaponConfig"))

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
	WeaponRequirement: string?, -- nil: shared; otherwise only this WeaponId.
	Enabled: boolean?, -- false reserves a definition whose gameplay effect is not implemented yet.
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
	RapidFire = {
		Id = "RapidFire", DisplayName = "高速連射", Description = "発射間隔を基本値の6%ずつ追加短縮",
		Category = "Weapon", MaxLevel = 3, Weight = 1, WeaponRequirement = "AssaultRifle",
		Requirements = {}, ExcludedWeapons = {}, EffectType = "FireIntervalReduction", EffectValue = 0.06,
	},
	Stabilization = {
		Id = "Stabilization", DisplayName = "安定化", Description = "射撃中のSpread増加を軽減（未実装）",
		Category = "Weapon", MaxLevel = 3, Weight = 1, WeaponRequirement = "AssaultRifle", Enabled = false,
		Requirements = {}, ExcludedWeapons = {}, EffectType = "SpreadGrowthReduction", EffectValue = 0,
	},
	ExtraPellets = {
		Id = "ExtraPellets", DisplayName = "追加ペレット", Description = "1Lvにつきペレット数+2",
		Category = "Weapon", MaxLevel = 3, Weight = 1, WeaponRequirement = "Shotgun",
		Requirements = {}, ExcludedWeapons = {}, EffectType = "PelletCountBonus", EffectValue = 2,
	},
	TightSpread = {
		Id = "TightSpread", DisplayName = "集弾強化", Description = "Spreadを基本値の15%ずつ縮小",
		Category = "Weapon", MaxLevel = 3, Weight = 1, WeaponRequirement = "Shotgun",
		Requirements = {}, ExcludedWeapons = {}, EffectType = "SpreadReduction", EffectValue = 0.15,
	},
	CriticalChanceUp = {
		Id = "CriticalChanceUp", DisplayName = "CriticalChance強化", Description = "1Lvにつきクリティカル率+5ポイント",
		Category = "Weapon", MaxLevel = 5, Weight = 1, WeaponRequirement = "Handgun",
		Requirements = {}, ExcludedWeapons = {}, EffectType = "CriticalChanceBonus", EffectValue = 0.05,
	},
	Ricochet = {
		Id = "Ricochet", DisplayName = "Ricochet", Description = "命中後に別の敵へ跳弾（未実装）",
		Category = "Weapon", MaxLevel = 3, Weight = 1, WeaponRequirement = "Handgun", Enabled = false,
		Requirements = {}, ExcludedWeapons = {}, EffectType = "RicochetCount", EffectValue = 1,
	},
}
local ids = table.freeze({
	"DamageUp", "FireRateUp", "MagazineUp", "RapidFire", "Stabilization",
	"ExtraPellets", "TightSpread", "CriticalChanceUp", "Ricochet",
})
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

function UpgradeConfig.IsWeaponCompatible(upgradeId: string, weaponId: string): boolean
	local definition = definitions[upgradeId]
	return definition ~= nil and WeaponConfig.GetWeaponConfig(weaponId) ~= nil and definition.Enabled ~= false
		and (definition.WeaponRequirement == nil or definition.WeaponRequirement == weaponId)
		and not table.find(definition.ExcludedWeapons, weaponId)
end

function UpgradeConfig.CanApplyUpgrade(upgradeId: string, weaponId: string, upgrades: { [string]: number }): boolean
	local definition = definitions[upgradeId]
	if not definition or not UpgradeConfig.IsWeaponCompatible(upgradeId, weaponId)
		or (upgrades[upgradeId] or 0) >= definition.MaxLevel then
		return false
	end
	-- Requirements lists upgrade IDs that must already have at least one level.
	for _, requiredId in definition.Requirements do
		if (upgrades[requiredId] or 0) < 1 then return false end
	end
	return true
end

function UpgradeConfig.GetEligibleUpgradeIds(weaponId: string, upgrades: { [string]: number }): { string }
	local eligible: { string } = {}
	for _, id in ids do
		if UpgradeConfig.CanApplyUpgrade(id, weaponId, upgrades) then table.insert(eligible, id) end
	end
	return eligible
end

return table.freeze(UpgradeConfig)
