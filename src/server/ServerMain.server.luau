--!strict

-- Server entry point: initialize authoritative game services.
local CombatService = require(script.Parent:WaitForChild("Services"):WaitForChild("CombatService"))
local EnemyService = require(script.Parent:WaitForChild("Services"):WaitForChild("EnemyService"))
local PlayerStateService = require(script.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))
local ProgressionService = require(script.Parent:WaitForChild("Services"):WaitForChild("ProgressionService"))
local ExperienceOrbService = require(script.Parent:WaitForChild("Services"):WaitForChild("ExperienceOrbService"))
local StageService = require(script.Parent:WaitForChild("Services"):WaitForChild("StageService"))
local SpawnService = require(script.Parent:WaitForChild("Services"):WaitForChild("SpawnService"))
local WeaponSelectionService = require(script.Parent:WaitForChild("Services"):WaitForChild("WeaponSelectionService"))
local SpecialEquipmentService = require(script.Parent:WaitForChild("Services"):WaitForChild("SpecialEquipmentService"))
local Grenade = require(script.Parent:WaitForChild("ServerModules"):WaitForChild("SpecialEquipment"):WaitForChild("Grenade"))
local EnergyShield = require(script.Parent:WaitForChild("ServerModules"):WaitForChild("SpecialEquipment"):WaitForChild("EnergyShield"))

-- Wire service communication here to avoid mutual require dependencies.
PlayerStateService.Init()
EnergyShield.Init()
SpecialEquipmentService.Init()
ProgressionService.Init()
ExperienceOrbService.Init()
CombatService.Init(EnemyService.ApplyDamage)
EnemyService.Init(ExperienceOrbService.SpawnOrb)
Grenade.Init(EnemyService.GetEnemiesInRadius, EnemyService.ApplyDamage)
assert(SpecialEquipmentService.RegisterSpecial("Grenade", Grenade.Use), "Grenade registration failed")
assert(SpecialEquipmentService.RegisterSpecial("EnergyShield", EnergyShield.Use), "EnergyShield registration failed")
StageService.Init()
WeaponSelectionService.Init()
SpawnService.Init()

print("Server initialization complete")
