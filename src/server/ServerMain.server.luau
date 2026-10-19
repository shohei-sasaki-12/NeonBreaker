--!strict

-- Server entry point: initialize authoritative game services.
local CombatService = require(script.Parent:WaitForChild("Services"):WaitForChild("CombatService"))
local EnemyService = require(script.Parent:WaitForChild("Services"):WaitForChild("EnemyService"))

-- Wire service communication here to avoid mutual require dependencies.
CombatService.Init(EnemyService.ApplyDamage)
EnemyService.Init()

print("Server initialization complete")
