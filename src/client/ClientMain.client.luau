--!strict

-- Client entry point: initialize local presentation and input controllers.
local CameraController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("CameraController"))

CameraController.Init()

print("Client initialization complete")
