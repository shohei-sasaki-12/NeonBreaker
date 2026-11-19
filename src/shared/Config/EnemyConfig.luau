--!strict

local Aegis = require(script.Parent:WaitForChild("AegisWalkerConfig"))
local Titan = require(script.Parent:WaitForChild("CoreTitanConfig"))

export type ShieldDefinition = { Capacity: number, ArcDegrees: number, RecoveryTime: number }

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
	IsMechanical: boolean?, -- EMP only affects explicitly mechanical enemies.
	IsBoss: boolean?, -- Bosses receive a slow instead of a full stun.
	Color: Color3?,
	Scale: number?,
	FallbackTemplate: string?,
	Ranged: { MinDistance: number, MaxDistance: number, ProjectileSpeed: number }?,
	Charge: { MinDistance: number, Range: number, Windup: number, Duration: number, SpeedMultiplier: number }?,
	Slam: { Radius: number, Windup: number }?,
	Support: { RetreatDistance: number, Radius: number, Heal: number }?,
	Shield: ShieldDefinition?,
	KnockbackResistance: number?,
	RootDensityMultiplier: number?,
	DamageReduction: number?,
	WeakPointMultiplier: number?,
}

local definitions: { [string]: EnemyDefinition } = {
	CoreTitan = {
		EnemyId = Titan.Id, AIType = "Boss", IsMechanical = true, IsBoss = true, FallbackTemplate = "Striker",
		MaxHP = Titan.MaxHP, MoveSpeed = Titan.MoveSpeed, Scale = Titan.Scale, Damage = Titan.Gatling.Damage,
		AttackRange = Titan.Gatling.Range, AttackCooldown = Titan.Recovery[1], DamageReduction = Titan.DamageReduction,
		ExperienceReward = 0, ThreatCost = 0, WeakPointMultiplier = Titan.WeakPointMultiplier,
	},
	AegisWalker = {
		EnemyId = Aegis.Id, AIType = "Boss", IsMechanical = true, IsBoss = true, FallbackTemplate = "Striker",
		MaxHP = Aegis.MaxHP, MoveSpeed = Aegis.MoveSpeed, Scale = Aegis.Scale,
		Damage = Aegis.Gun.Damage, AttackRange = Aegis.Gun.Range, AttackCooldown = Aegis.AttackRecovery,
		DamageReduction = Aegis.DamageReduction, ExperienceReward = Aegis.ExperienceReward, ThreatCost = 0,
	},
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
		IsMechanical = true,
	},
	ShooterDrone = {
		EnemyId = "ShooterDrone", AIType = "Ranged", IsMechanical = true, FallbackTemplate = "Striker",
		MaxHP = 60, MoveSpeed = 12, Damage = 10, AttackRange = 70, AttackCooldown = 1.5,
		ExperienceReward = 2, ThreatCost = 2, Color = Color3.fromRGB(80, 175, 255),
		Ranged = { MinDistance = 24, MaxDistance = 45, ProjectileSpeed = 65 },
	},
	Ripper = {
		EnemyId = "Ripper", AIType = "Charge", IsMechanical = true, FallbackTemplate = "Striker",
		MaxHP = 40, MoveSpeed = 24, Damage = 12, AttackRange = 3.5, AttackCooldown = 0.8,
		ExperienceReward = 2, ThreatCost = 2, Color = Color3.fromRGB(230, 70, 90), Scale = 0.9,
		Charge = { MinDistance = 7, Range = 20, Windup = 0.5, Duration = 0.4, SpeedMultiplier = 2.3 },
	},
	Guardian = {
		EnemyId = "Guardian", AIType = "Ranged", IsMechanical = true, FallbackTemplate = "Striker",
		MaxHP = 180, MoveSpeed = 10, Damage = 15, AttackRange = 30, AttackCooldown = 1.8,
		ExperienceReward = 4, ThreatCost = 4, Color = Color3.fromRGB(120, 155, 215),
		Ranged = { MinDistance = 0, MaxDistance = 24, ProjectileSpeed = 60 },
		Shield = { Capacity = 80, ArcDegrees = 120, RecoveryTime = 5 },
	},
	SupportNode = {
		EnemyId = "SupportNode", AIType = "Support", IsMechanical = true, FallbackTemplate = "Striker",
		MaxHP = 100, MoveSpeed = 10, Damage = 5, AttackRange = 40, AttackCooldown = 2.5,
		ExperienceReward = 5, ThreatCost = 4, Color = Color3.fromRGB(85, 230, 135),
		Support = { RetreatDistance = 24, Radius = 22, Heal = 12 },
	},
	Bulwark = {
		EnemyId = "Bulwark", AIType = "Slam", IsMechanical = true, FallbackTemplate = "Striker",
		MaxHP = 350, MoveSpeed = 8, Damage = 25, AttackRange = 6, AttackCooldown = 2,
		ExperienceReward = 5, ThreatCost = 5, Color = Color3.fromRGB(190, 110, 55), Scale = 1.25,
		Slam = { Radius = 8, Windup = 0.85 }, KnockbackResistance = 0.85,
		RootDensityMultiplier = 4,
	},
}

for _, definition in definitions do
	for _, value in definition do
		if typeof(value) == "table" then table.freeze(value) end
	end
	table.freeze(definition)
end
table.freeze(definitions)

local EnemyConfig = {}

function EnemyConfig.GetEnemyConfig(enemyId: string): EnemyDefinition?
	return definitions[enemyId]
end

return table.freeze(EnemyConfig)
