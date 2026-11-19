--!strict

-- Client entry point: initialize local presentation and input controllers.
local CameraController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("CameraController"))
local CrosshairController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("CrosshairController"))
local InputController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("InputController"))
local WeaponController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponController"))
local LevelUpController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("LevelUpController"))
local WeaponEffectsController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponEffectsController"))
local WeaponSelectionController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponSelectionController"))
local SpecialEquipmentController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("SpecialEquipmentController"))
local SpecialEffectsController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("SpecialEffectsController"))
local StageAlertController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("StageAlertController"))
local DashController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("DashController"))

-- Subscribe consumers before enabling input notifications.
CameraController.Init()
CrosshairController.Init()
WeaponEffectsController.Init()
WeaponController.Init()
SpecialEquipmentController.Init()
SpecialEffectsController.Init()
DashController.Init()
InputController.Init()
LevelUpController.Init()
StageAlertController.Init()
WeaponSelectionController.Init()

print("Client initialization complete")
