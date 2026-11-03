--!strict

-- Initial prototype tuning. Cooldown/MaxLevel live in SpecialEquipmentConfig.
return table.freeze({
	Damage = 60,
	BlastRadius = 12,
	FuseTime = 2,
	ThrowSpeed = 60,
	MultiAngleStep = 8, -- Degrees between simultaneous throws; centered around the aim direction.
	UpwardSpeed = 25,
	GravityScale = 1,
	MaxSimulationStep = 1 / 30,
	Diameter = 0.8,
	LaunchOffset = 2,
	CollisionPadding = 0.05,
	RequireBlastLineOfSight = true,
	ProjectileColor = Color3.fromRGB(55, 85, 45),
	ExplosionColor = Color3.fromRGB(255, 170, 60),
	ExplosionDuration = 0.35,
	ExplosionBrightness = 4,
	EffectLifetime = 0.5,
})
