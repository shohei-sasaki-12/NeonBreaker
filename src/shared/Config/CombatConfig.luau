--!strict

return table.freeze({
	DefaultWeaponId = "AssaultRifle",
	MaxOriginDistance = 16, -- Allows the current shoulder camera plus movement latency.
	DirectionMagnitudeTolerance = 0.01,
	FireTimingTolerance = 0.02, -- Bounded arrival jitter; never subtract from the next shot's interval.
	RemoteRequestsPerSecond = 24,
	RemoteBurstSize = 12,
	LogHits = true,
})
