--!strict

return table.freeze({
	Id = "AegisWalker",
	DisplayName = "AEGIS WALKER",
	MaxHP = 8000,
	MoveSpeed = 8,
	DamageReduction = 0.10,
	ExperienceReward = 50,
	Scale = 2.2,
	IntroDuration = 3,
	SpawnOffset = 6.5,
	FallbackPosition = Vector3.new(0, 0, -44),
	EncounterSpawnMultiplier = 0.5,
	AttackRecovery = 1.4,
	TrackingRate = 7,
	Gun = table.freeze({ Range = 100, Windup = 0.9, Duration = 2.5, Interval = 0.18, Speed = 95, Damage = 7 }),
	Missile = table.freeze({ Windup = 1.15, Stagger = 0.2, Radius = 8, Damage = 24, FallHeight = 32 }),
	Stomp = table.freeze({ TriggerRange = 11, Windup = 0.95, Radius = 13, WaveDuration = 0.35, Damage = 30 }),
	Reinforcement = table.freeze({ Interval = 19, Radius = 17, MinPlayerDistance = 10, WaveSize = table.freeze({ 2, 3, 4, 5 }) }),
	HealingDrop = table.freeze({ Amount = 50, Radius = 5, Lifetime = 45, CheckInterval = 0.15 }),
})
