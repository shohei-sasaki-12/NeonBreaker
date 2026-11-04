--!strict

-- Prototype tuning. Cooldown lives in SpecialEquipmentConfig.
return table.freeze({
	Duration = 10,
	Damage = 8,
	FireInterval = 0.5,
	Range = 60,
	GroundProbeDistance = 16,
	BaseSize = Vector3.new(2, 1, 2),
	BarrelSize = Vector3.new(0.5, 0.5, 2),
	GunHeight = 1.5,
	BaseColor = Color3.fromRGB(45, 65, 80),
	BarrelColor = Color3.fromRGB(70, 210, 255),
	TracerColor = Color3.fromRGB(100, 230, 255),
	TracerThickness = 0.08,
	TracerDuration = 0.08,
})
