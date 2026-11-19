--!strict

return table.freeze({
	Id = "CoreTitan", DisplayName = "CORE TITAN",
	MaxHP = 30000, DamageReduction = 0.15, MoveSpeed = 6, Scale = 2.8,
	SpawnPosition = Vector3.new(0, 0, -40), SpawnHeight = 8, IntroDuration = 3, ClearDuration = 2,
	Phase2At = 0.70, Phase3At = 0.35,
	Recovery = table.freeze({ 1.6, 1.35, 1.0 }),
	WeakPointMultiplier = 2, ExposureDuration = 2.5,
	Gatling = table.freeze({ Range = 125, Windup = 0.9, Duration = 2.7, Interval = 0.16, Speed = 115, Damage = 8, Tracking = 7 }),
	Missile = table.freeze({ Radius = 7, Windup = 1.25, Stagger = 0.24, Damage = 25, FallHeight = 30, SoloOffset = 9 }),
	Sweep = table.freeze({ Radius = 17, ArcDegrees = 150, Windup = 1.1, Damage = 28 }),
	Rotation = table.freeze({ Range = 48, Windup = 1, Duration = 3.5, ArcDegrees = 250, Width = 3, Damage = 16, HitInterval = 0.55 }),
	Drones = table.freeze({ Count = 4, Radius = 18, MinPlayerDistance = 9, Windup = 1 }),
	Wall = table.freeze({ Windup = 1.2, Duration = 3.0, ForwardOffset = 13, Width = 3, HalfLength = 22, Gap = 10, Damage = 18 }),
	Overload = table.freeze({ Radius = 8, Windup = 1.35, Stagger = 0.28, Damage = 29, ForwardOffset = 15 }),
	Charge = table.freeze({ Range = 32, HalfWidth = 5, Windup = 1.15, Speed = 50, Damage = 34 }),
	Combined = table.freeze({ LaserArcDegrees = 150, MissileOffset = 12 }),
	SafeLane = table.freeze({ Offset = 14, Width = 8, Length = 70 }),
})
