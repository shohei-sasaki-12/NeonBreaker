--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("FireConfig"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("StatusEffect"))
local PlayerStateService = require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

type EffectHandler = (Model, Types.Definition) -> boolean
local applyEffect: EffectHandler? = nil
local random = Random.new()
local Fire = {}

-- Called once per enemy hit by an accepted weapon shot, never by DoT or special equipment.
function Fire.OnHit(player: Player, enemy: Model): boolean
	assert(RunService:IsServer(), "Fire must be processed on the server")
	local handler = applyEffect
	local state = PlayerStateService.GetState(player)
	if not handler or player.Parent ~= Players or not state then return false end
	local level = Config.GetLevelConfig(state.Upgrades.Fire or 0)
	if not level or random:NextNumber() >= level.Chance then return false end
	return handler(enemy, {
		EffectId = Config.EffectId, Duration = level.Duration, SourcePlayer = player,
		Stack = 1, StackMode = "Refresh", TickDamage = level.TickDamage, SlowRate = 0,
	})
end

function Fire.Init(handler: EffectHandler)
	assert(RunService:IsServer(), "Fire must run on the server")
	if applyEffect then return end
	assert(typeof(handler) == "function", "Fire requires an effect handler")
	applyEffect = handler
end

function Fire.Destroy()
	applyEffect = nil
end

return Fire
