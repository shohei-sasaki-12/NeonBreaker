--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("CryoConfig"))
local PlayerStateService = require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

type CoolingHandler = (Model, number) -> boolean
local addCooling: CoolingHandler? = nil
local Cryo = {}

function Cryo.OnHit(player: Player, enemy: Model): boolean
	assert(RunService:IsServer(), "Cryo must be processed on the server")
	local handler = addCooling
	local state = PlayerStateService.GetState(player)
	if not handler or player.Parent ~= Players or not state then return false end
	local level = state.Upgrades.Cryo or 0
	if not Config.GetLevelConfig(level) then return false end
	return handler(enemy, level)
end

function Cryo.Init(handler: CoolingHandler)
	assert(RunService:IsServer(), "Cryo must run on the server")
	if addCooling then return end
	assert(typeof(handler) == "function", "Cryo requires a cooling handler")
	addCooling = handler
end

function Cryo.Destroy()
	addCooling = nil
end

return Cryo
