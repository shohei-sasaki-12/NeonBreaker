--!strict

return table.freeze({
	ThreatCostMultiplier = 2,
	HealthMultiplier = 2,
	DamageMultiplier = 1.3,
	MoveSpeedMultiplier = 1.1,
	ExperienceMultiplier = 2,
	ScaleMultiplier = 1.1,
	OutlineColor = Color3.fromRGB(255, 188, 60),
	Abilities = table.freeze({ "ExplosionOnDeath", "EnergyShield" }),
	ShieldCapacity = 60,
	ExplosionRadius = 9,
	ExplosionDamage = 24,
	ExplosionLifetime = 0.25,
})
