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
	SpecialRequirement: string?, -- Special upgrades require this equipped special.
	Enabled: boolean?, -- false reserves a definition whose gameplay effect is not implemented yet.
}

local definitions: { [string]: UpgradeDefinition } = {
	Electric = {
		Id = "Electric", DisplayName = "Electric", Description = "Weapon hits may chain lightning to 1/2/3 additional enemies. Chain damage is reduced.",
		Category = "Weapon", MaxLevel = 3, Weight = 1,
		Requirements = {}, ExcludedWeapons = {}, EffectType = "ElectricLevel", EffectValue = 1,
	},
	Fire = {
		Id = "Fire", DisplayName = "Fire", Description = "Weapon hits may inflict Burn. Higher levels improve chance, damage or duration.",
		Category = "Weapon", MaxLevel = 3, Weight = 1,
		Requirements = {}, ExcludedWeapons = {}, EffectType = "FireLevel", EffectValue = 1,
	},
	GrenadeDamageUp = {
		Id = "GrenadeDamageUp", DisplayName = "Grenade Damage Up", Description = "Grenade damage +10% per level",
		Category = "Special", MaxLevel = 5, Weight = 1, SpecialRequirement = "Grenade",
		Requirements = {}, ExcludedWeapons = {}, EffectType = "SpecialDamageMultiplier", EffectValue = 0.10,
	},
	GrenadeRadiusUp = {
		Id = "GrenadeRadiusUp", DisplayName = "Grenade Radius Up", Description = "Blast radius +10% per level",
		Category = "Special", MaxLevel = 5, Weight = 1, SpecialRequirement = "Grenade",
		Requirements = {}, ExcludedWeapons = {}, EffectType = "SpecialRadiusMultiplier", EffectValue = 0.10,
	},
	GrenadeCooldownDown = {
		Id = "GrenadeCooldownDown", DisplayName = "Grenade Cooldown Down", Description = "Base cooldown -6% per level (next use)",
		Category = "Special", MaxLevel = 5, Weight = 1, SpecialRequirement = "Grenade",
		Requirements = {}, ExcludedWeapons = {}, EffectType = "SpecialCooldownReduction", EffectValue = 0.06,
	},
	MultiGrenade = {
		Id = "MultiGrenade", DisplayName = "Multi Grenade", Description = "Throw one additional grenade per level",
		Category = "Special", MaxLevel = 5, Weight = 1, SpecialRequirement = "Grenade",
		Requirements = {}, ExcludedWeapons = {}, EffectType = "SpecialCountBonus", EffectValue = 1,
	},
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
	"GrenadeDamageUp", "GrenadeRadiusUp", "GrenadeCooldownDown", "MultiGrenade",
	"Fire",
	"Electric",
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
		and definition.Category == "Weapon" and definition.SpecialRequirement == nil
		and (definition.WeaponRequirement == nil or definition.WeaponRequirement == weaponId)
		and not table.find(definition.ExcludedWeapons, weaponId)
end

function UpgradeConfig.CanApplyUpgrade(upgradeId: string, weaponId: string, upgrades: { [string]: number }, specialId: string?): boolean
	local definition = definitions[upgradeId]
	if not definition or definition.Enabled == false or (upgrades[upgradeId] or 0) >= definition.MaxLevel then
		return false
	end
	if definition.Category == "Special" then
		if not definition.SpecialRequirement or definition.SpecialRequirement ~= specialId then return false end
	elseif not UpgradeConfig.IsWeaponCompatible(upgradeId, weaponId) then
		return false
	end
	-- Requirements lists upgrade IDs that must already have at least one level.
	for _, requiredId in definition.Requirements do
		if (upgrades[requiredId] or 0) < 1 then return false end
	end
	return true
end

function UpgradeConfig.GetEligibleUpgradeIds(weaponId: string, upgrades: { [string]: number }, specialId: string?): { string }
	local eligible: { string } = {}
	for _, id in ids do
		if UpgradeConfig.CanApplyUpgrade(id, weaponId, upgrades, specialId) then table.insert(eligible, id) end
	end
	return eligible
end

return table.freeze(UpgradeConfig)
