--!strict

export type Definition = {
	EffectId: string,
	Duration: number,
	Stack: number?, -- Added on reapplication; defaults to 1.
	SourcePlayer: Player?, -- nil for environmental effects.
	TickDamage: number?, -- Damage per stack per configured tick; defaults to 0.
	SlowRate: number?, -- Reduction fraction [0, 1], not multiplied by Stack.
}

export type Snapshot = {
	EffectId: string, Duration: number, Stack: number, SourcePlayer: Player?,
	TickDamage: number, SlowRate: number, ExpiresAt: number, NextTickAt: number,
}

return table.freeze({})
