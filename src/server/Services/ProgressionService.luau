--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

-- Stateless rules service; PlayerStateService owns the committed player data.
local ProgressionService = {}

function ProgressionService.AddExperience(player: Player, amount: number): boolean
	assert(RunService:IsServer(), "XP must be granted on the server")
	local state = PlayerStateService.GetState(player)
	if not state or amount ~= amount or amount <= 0 or amount == math.huge or amount % 1 ~= 0
		or state.CurrentXP + amount > 9007199254740991 then
		return false
	end
	local level = state.Level
	local xp = state.CurrentXP + amount
	local requiredXP = Config.GetRequiredXP(level)
	while xp >= requiredXP do
		xp -= requiredXP
		level += 1
		requiredXP = Config.GetRequiredXP(level)
	end
	return PlayerStateService.UpdateProgression(player, level, xp, amount)
end

return ProgressionService
