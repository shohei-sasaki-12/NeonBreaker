--!strict

export type WeaponDefinition = {
	WeaponId: string,
	Damage: number,
	FireInterval: number,
	MagazineSize: number,
	ReloadTime: number,
	Range: number,
	CriticalChance: number,
	CriticalMultiplier: number,
	Penetration: number,
}

-- Add future weapon definitions here, keyed by WeaponId.
local definitions: { [string]: WeaponDefinition } = {
	AssaultRifle = {
		WeaponId = "AssaultRifle",
		Damage = 12,
		FireInterval = 0.125,
		MagazineSize = 30,
		ReloadTime = 2.0,
		Range = 180,
		CriticalChance = 0.05,
		CriticalMultiplier = 1.5,
		Penetration = 0,
	},
}

-- Base settings are shared constants; runtime weapon state belongs elsewhere.
for _, definition in definitions do
	table.freeze(definition)
end
table.freeze(definitions)

local WeaponConfig = {}

function WeaponConfig.GetWeaponConfig(weaponId: string): WeaponDefinition?
	return definitions[weaponId]
end

return table.freeze(WeaponConfig)
