--!strict

return table.freeze({
	EnemyPool = table.freeze({
		"Striker", "Striker", "Striker", "Striker",
		"ShooterDrone", "ShooterDrone", "Ripper", "Ripper",
		"Guardian", "SupportNode", "Bulwark",
	}),
	SpawnInterval = 3,
	MaxEnemies = 20,
	MinPlayerDistance = 30,
	SpawnHeightOffset = 3,
})
