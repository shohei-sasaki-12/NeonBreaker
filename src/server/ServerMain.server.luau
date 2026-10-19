--!strict

-- Server entry point: initialize authoritative game services.
local CombatService = require(script.Parent:WaitForChild("Services"):WaitForChild("CombatService"))
local EnemyService = require(script.Parent:WaitForChild("Services"):WaitForChild("EnemyService"))
local PlayerStateService = require(script.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))
local ProgressionService = require(script.Parent:WaitForChild("Services"):WaitForChild("ProgressionService"))
local ExperienceOrbService = require(script.Parent:WaitForChild("Services"):WaitForChild("ExperienceOrbService"))

-- Wire service communication here to avoid mutual require dependencies.
PlayerStateService.Init()
ProgressionService.Init()
ExperienceOrbService.Init()
CombatService.Init(EnemyService.ApplyDamage)
EnemyService.Init(ExperienceOrbService.SpawnOrb)

print("Server initialization complete")
