--!strict

export type SpecialDefinition = {
	SpecialId: string,
	Cooldown: number, -- Seconds; selected and applied by the server.
	MaxLevel: number,
}

local definitions: { [string]: SpecialDefinition } = {
	Grenade = { SpecialId = "Grenade", Cooldown = 12, MaxLevel = 5 },
}
for _, definition in definitions do table.freeze(definition) end
table.freeze(definitions)

local SpecialEquipmentConfig = { RequestInterval = 0.2 }

function SpecialEquipmentConfig.GetSpecialConfig(specialId: string): SpecialDefinition?
	return definitions[specialId]
end

return table.freeze(SpecialEquipmentConfig)
