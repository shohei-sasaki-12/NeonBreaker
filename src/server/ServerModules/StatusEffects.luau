--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("StatusEffectConfig"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("StatusEffect"))

export type Controller = {
	Apply: (Types.Definition) -> boolean,
	Remove: (string, Player?) -> boolean,
	GetEffects: () -> { Types.Snapshot },
	Update: () -> number, -- Strongest active SlowRate.
	Destroy: () -> (),
}
type DamageHandler = (number, Player?) -> boolean
type Entry = Types.Snapshot
local StatusEffects = {}

local function Finite(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function Valid(effect: Types.Definition): boolean
	if typeof(effect) ~= "table" or typeof(effect.EffectId) ~= "string" or #effect.EffectId == 0
		or #effect.EffectId > Config.MaxEffectIdLength or not Finite(effect.Duration)
		or effect.Duration <= 0 or effect.Duration > Config.MaxDuration then return false end
	local stack = if effect.Stack == nil then 1 else effect.Stack
	local damage = if effect.TickDamage == nil then 0 else effect.TickDamage
	local slow = if effect.SlowRate == nil then 0 else effect.SlowRate
	if effect.StackMode ~= nil and effect.StackMode ~= "Add" and effect.StackMode ~= "Refresh" then return false end
	if not Finite(stack) or stack < 1 or stack > Config.MaxStack or stack % 1 ~= 0
		or not Finite(damage) or damage < 0 or not Finite(slow) or slow < 0 or slow > 1
		or not Finite(damage * Config.MaxStack * math.ceil(Config.MaxDuration / Config.TickInterval)) then return false end
	local source = effect.SourcePlayer
	return source == nil or (typeof(source) == "Instance" and source:IsA("Player") and source.Parent == Players)
end

function StatusEffects.new(damage: DamageHandler): Controller
	assert(RunService:IsServer(), "Status effects must run on the server")
	local entries: { Entry } = {}
	local active = true
	local updating = false
	local function Update(): number
		if not active or updating then return 0 end
		updating = true
		local now = Workspace:GetServerTimeNow()
		-- Iterate a snapshot: damage/death callbacks may destroy or remove effects.
		for _, entry in table.clone(entries) do
			if not active then break end
			if not table.find(entries, entry) then continue end
			local untilTime = math.min(now, entry.ExpiresAt)
			if untilTime >= entry.NextTickAt then
				local ticks = math.floor((untilTime - entry.NextTickAt) / Config.TickInterval) + 1
				-- Commit the schedule before calling damage to prevent duplicate/reentrant ticks.
				entry.NextTickAt += ticks * Config.TickInterval
				if entry.TickDamage > 0 then
					local source = entry.SourcePlayer
					if source and source.Parent ~= Players then source = nil end
					damage(entry.TickDamage * entry.Stack * ticks, source)
				end
			end
			local index = table.find(entries, entry)
			if index and now >= entry.ExpiresAt then table.remove(entries, index) end
		end
		updating = false
		local slow = 0
		if active then
			for _, entry in entries do
				if now < entry.ExpiresAt then slow = math.max(slow, entry.SlowRate) end
			end
		end
		return slow
	end
	return {
		Apply = function(effect: Types.Definition): boolean
			assert(RunService:IsServer(), "Status effects must be applied on the server")
			if not active or updating or not Valid(effect) then return false end
			-- Settle elapsed ticks using the old stack/source before replacing or refreshing.
			Update()
			if not active then return false end
			local now = Workspace:GetServerTimeNow()
			local current: Entry? = nil
			for _, entry in entries do
				if entry.EffectId == effect.EffectId and entry.SourcePlayer == effect.SourcePlayer then current = entry; break end
			end
			if not current then
				if #entries >= Config.MaxEffectsPerEnemy then return false end
				current = {
					EffectId = effect.EffectId, Duration = effect.Duration, Stack = 0, SourcePlayer = effect.SourcePlayer,
					TickDamage = 0, SlowRate = 0, ExpiresAt = now + effect.Duration, NextTickAt = now + Config.TickInterval,
				}
				table.insert(entries, current)
			end
			current.Stack = if effect.StackMode == "Refresh" then (effect.Stack or 1)
				else math.min(Config.MaxStack, current.Stack + (effect.Stack or 1))
			current.Duration = effect.Duration
			current.ExpiresAt = now + effect.Duration
			current.TickDamage = effect.TickDamage or 0
			current.SlowRate = effect.SlowRate or 0
			-- Preserve the next tick across refreshes so frequent hits cannot postpone damage forever.
			return true
		end,
		Remove = function(id: string, source: Player?): boolean
			assert(RunService:IsServer(), "Status effects must be removed on the server")
			if not active then return false end
			for index, entry in entries do
				if entry.EffectId == id and entry.SourcePlayer == source then table.remove(entries, index); return true end
			end
			return false
		end,
		GetEffects = function(): { Types.Snapshot }
			local snapshots: { Types.Snapshot } = {}
			for _, entry in entries do table.insert(snapshots, table.freeze(table.clone(entry))) end
			return table.freeze(snapshots)
		end,
		Update = Update,
		Destroy = function()
			active = false
			table.clear(entries)
		end,
	}
end

return StatusEffects
