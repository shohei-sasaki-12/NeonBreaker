--!strict

-- Prototype tuning. Each jump searches from the previous hit position.
local counts = table.freeze({ 1, 2, 3 })
local ElectricConfig = {
	Chance = 0.20,
	ChainRange = 18,
	DamageMultiplier = 0.50, -- Each jump uses this fraction of the original weapon hit.
	TracerColor = Color3.fromRGB(180, 150, 255),
	TracerThickness = 0.12,
	TracerDuration = 0.15,
}

function ElectricConfig.GetChainCount(level: number): number
	return counts[level] or 0
end

return table.freeze(ElectricConfig)
