--!strict

-- Client entry point: initialize local presentation and input controllers.
local CameraController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("CameraController"))
local InputController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("InputController"))
local WeaponController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("WeaponController"))
local LevelUpController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("LevelUpController"))

-- Subscribe consumers before enabling input notifications.
CameraController.Init()
WeaponController.Init()
InputController.Init()
LevelUpController.Init()

print("Client initialization complete")
