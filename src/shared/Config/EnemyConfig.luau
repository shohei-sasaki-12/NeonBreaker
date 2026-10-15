--!strict

export type EnemyDefinition = {
	EnemyId: string,
	MaxHP: number,
	MoveSpeed: number,
	Damage: number,
	AttackRange: number,
	AttackCooldown: number,
	ExperienceReward: number,
	ThreatCost: number,
	AIType: string,
}

local definitions: { [string]: EnemyDefinition } = {
	Striker = {
		EnemyId = "Striker",
		MaxHP = 80,
		MoveSpeed = 16,
		Damage = 15,
		AttackRange = 4,
		AttackCooldown = 1.2,
		ExperienceReward = 1,
		ThreatCost = 1,
		AIType = "Melee",
	},
}

for _, definition in definitions do
	table.freeze(definition)
end
table.freeze(definitions)

local EnemyConfig = {}

function EnemyConfig.GetEnemyConfig(enemyId: string): EnemyDefinition?
	return definitions[enemyId]
end

return table.freeze(EnemyConfig)
