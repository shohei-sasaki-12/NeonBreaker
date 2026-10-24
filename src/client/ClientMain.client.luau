--!strict

-- Client entry point: initialize local presentation and input controllers.
local CameraController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("CameraController"))
local InputController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("InputController"))
local WeaponController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponController"))
local LevelUpController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("LevelUpController"))
local WeaponEffectsController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponEffectsController"))
local WeaponSelectionController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponSelectionController"))

-- Subscribe consumers before enabling input notifications.
CameraController.Init()
WeaponEffectsController.Init()
WeaponController.Init()
InputController.Init()
LevelUpController.Init()
WeaponSelectionController.Init()

print("Client initialization complete")
