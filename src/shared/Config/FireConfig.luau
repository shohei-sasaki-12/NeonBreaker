--!strict

export type LevelDefinition = { Chance: number, Duration: number, TickDamage: number }
local levels: { LevelDefinition } = {
	{ Chance = 0.15, Duration = 3, TickDamage = 3 },
	{ Chance = 0.20, Duration = 3, TickDamage = 5 },
	{ Chance = 0.25, Duration = 4, TickDamage = 5 },
}
for _, level in levels do table.freeze(level) end
table.freeze(levels)

local FireConfig = { EffectId = "Burn" }

function FireConfig.GetLevelConfig(level: number): LevelDefinition?
	return levels[level]
end

return table.freeze(FireConfig)
