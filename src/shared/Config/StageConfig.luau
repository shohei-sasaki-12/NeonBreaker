--!strict

export type PhaseId = "A" | "B" | "C" | "D" | "FinalRush"
export type Phase = {
	Id: PhaseId,
	StartAt: number,
	ThreatBudget: number,
	SpawnInterval: number,
	WaveSize: number,
	EnemyPool: { string },
	EliteChance: number,
}

local phases: { Phase } = {
	{ Id = "A", StartAt = 0, ThreatBudget = 10, SpawnInterval = 3, WaveSize = 1,
		EnemyPool = { "Striker", "Striker", "ShooterDrone" }, EliteChance = 0 },
	{ Id = "B", StartAt = 180, ThreatBudget = 16, SpawnInterval = 3, WaveSize = 2,
		EnemyPool = { "Striker", "Striker", "ShooterDrone", "Ripper" }, EliteChance = 0 },
	{ Id = "C", StartAt = 360, ThreatBudget = 22, SpawnInterval = 2.5, WaveSize = 3,
		EnemyPool = { "Striker", "Striker", "ShooterDrone", "Ripper", "Guardian", "SupportNode" }, EliteChance = 0.12 },
	{ Id = "D", StartAt = 600, ThreatBudget = 28, SpawnInterval = 2, WaveSize = 4,
		EnemyPool = { "Striker", "ShooterDrone", "Ripper", "Guardian", "SupportNode", "Bulwark" }, EliteChance = 0.12 },
	{ Id = "FinalRush", StartAt = 840, ThreatBudget = 40, SpawnInterval = 1.5, WaveSize = 5,
		EnemyPool = { "Striker", "ShooterDrone", "Ripper", "Guardian", "SupportNode", "Bulwark" }, EliteChance = 0.28 },
}
for _, phase in phases do
	table.freeze(phase.EnemyPool)
	table.freeze(phase)
end

local StageConfig = {
	StageId = "TestStage",
	CountdownDuration = 3,
	RunningDuration = 900,
	SnapshotRequestInterval = 1,
	Phases = table.freeze(phases),
	MidBossEventAt = 600,
	DropPod = table.freeze({
		StartAt = 300,
		WarningDuration = 3,
		FallHeight = 42,
		Size = Vector3.new(6, 9, 6),
		ProbeHeight = 64,
		ProbeDepth = 128,
		FallbackSites = table.freeze({
			Vector3.new(-100, 0, -80), Vector3.new(100, 0, -80),
			Vector3.new(100, 0, 80), Vector3.new(-100, 0, 80),
		}),
	}),
}

function StageConfig.GetPhase(elapsed: number): Phase
	for i = #phases, 2, -1 do
		if elapsed >= phases[i].StartAt then return phases[i] end
	end
	return phases[1]
end

return table.freeze(StageConfig)
