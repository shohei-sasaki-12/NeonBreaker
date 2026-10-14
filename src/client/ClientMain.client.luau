--!strict

-- Client entry point: initialize local presentation and input controllers.
local CameraController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("CameraController"))
local InputController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("InputController"))

-- Subscribe consumers before enabling input notifications.
CameraController.Init()
InputController.Init()

print("Client initialization complete")
