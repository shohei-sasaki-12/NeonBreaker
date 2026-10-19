--!strict

local ProgressionConfig = {
	InitialLevel = 1,
	BaseRequiredXP = 10,
	RequiredXPPerLevel = 5,
}

function ProgressionConfig.GetRequiredXP(level: number): number
	return math.floor(ProgressionConfig.BaseRequiredXP + level * ProgressionConfig.RequiredXPPerLevel)
end

return table.freeze(ProgressionConfig)
