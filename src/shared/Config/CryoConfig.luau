--!strict

export type LevelDefinition = { CoolingPerHit: number, SlowRate: number }
local levels: { LevelDefinition } = {
	{ CoolingPerHit = 25, SlowRate = 0.20 },
	{ CoolingPerHit = 35, SlowRate = 0.35 },
	{ CoolingPerHit = 50, SlowRate = 0.50 },
}
for _, level in levels do table.freeze(level) end
table.freeze(levels)

local CryoConfig = {
	SlowThreshold = 50,
	FreezeThreshold = 100,
	MaxCooling = 100,
	SlowDuration = 3,
	FreezeDuration = 1.5,
	FreezeImmunityDuration = 3, -- Starts when Freeze ends.
	DecayDelay = 2,
	DecayPerSecond = 15,
	BossMaxSlowRate = 0.35,
}

function CryoConfig.GetLevelConfig(level: number): LevelDefinition?
	return levels[level]
end

return table.freeze(CryoConfig)
