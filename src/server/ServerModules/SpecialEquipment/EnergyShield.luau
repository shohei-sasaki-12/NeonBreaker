--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EnergyShieldConfig"))
local PlayerStateService = require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

type ShieldState = { Character: Model, Humanoid: Humanoid, Value: number, ExpiresAt: number, Connections: { RBXScriptConnection } }
local shields: { [Player]: ShieldState } = {}
local connections: { RBXScriptConnection } = {}
local started = false
local EnergyShield = {}

local function Publish(player: Player, shield: ShieldState?)
	-- Display/debug mirrors only. Damage calculations never read these attributes.
	player:SetAttribute("ShieldValue", if shield then shield.Value else 0)
	player:SetAttribute("ShieldCapacity", if shield then Config.Capacity else 0)
	player:SetAttribute("ShieldExpiresAt", if shield then shield.ExpiresAt else 0)
end

local function Clear(player: Player)
	local shield = shields[player]
	shields[player] = nil
	if shield then
		for _, connection in shield.Connections do connection:Disconnect() end
	end
	Publish(player, nil)
end

local function GetActive(player: Player): ShieldState?
	local shield = shields[player]
	if not shield then return nil end
	local state = PlayerStateService.GetState(player)
	if not started or player.Parent ~= Players or not state or state.CurrentSpecial ~= "EnergyShield"
		or player.Character ~= shield.Character or not shield.Character.Parent or shield.Humanoid.Health <= 0
		or shield.Value <= 0 or Workspace:GetServerTimeNow() >= shield.ExpiresAt then
		Clear(player)
		return nil
	end
	return shield
end

-- Called by the registered special handler after ownership, life and cooldown validation.
function EnergyShield.Use(player: Player, _level: number, _direction: Vector3)
	assert(started and RunService:IsServer(), "EnergyShield must be initialized on the server")
	local state = PlayerStateService.GetState(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	assert(player.Parent == Players and state and state.CurrentSpecial == "EnergyShield"
		and character and character.Parent and humanoid and humanoid.Health > 0, "EnergyShield requires a living owner")
	local shield: ShieldState = {
		Character = character, Humanoid = humanoid, Value = Config.Capacity,
		ExpiresAt = Workspace:GetServerTimeNow() + Config.Duration, Connections = {},
	}
	-- Replace rather than stack; never modify Humanoid.Health or MaxHealth.
	if shields[player] then Clear(player) end
	shields[player] = shield
	table.insert(shield.Connections, humanoid.Died:Connect(function()
		if shields[player] == shield then Clear(player) end
	end))
	table.insert(shield.Connections, player.CharacterRemoving:Connect(function(removing: Model)
		if removing == character and shields[player] == shield then Clear(player) end
	end))
	Publish(player, shield)
end

-- Server-only damage filter. Returns the remainder to apply to HP.
function EnergyShield.AbsorbDamage(player: Player, amount: number): number
	assert(RunService:IsServer(), "Shield damage must run on the server")
	assert(amount == amount and amount > 0 and amount < math.huge, "Shield damage must be finite and positive")
	local shield = GetActive(player)
	if not shield then return amount end
	local absorbed = math.min(amount, shield.Value)
	shield.Value -= absorbed
	if shield.Value <= 0 then Clear(player) else Publish(player, shield) end
	return amount - absorbed
end

function EnergyShield.Init()
	if started then return end
	assert(RunService:IsServer(), "EnergyShield must run on the server")
	started = true
	table.insert(connections, RunService.Heartbeat:Connect(function()
		for player in shields do GetActive(player) end
	end))
	table.insert(connections, PlayerStateService.SpecialChanged:Connect(function(player: Player)
		GetActive(player)
	end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
		Clear(player)
		player:SetAttribute("ShieldValue", nil)
		player:SetAttribute("ShieldCapacity", nil)
		player:SetAttribute("ShieldExpiresAt", nil)
	end))
end

function EnergyShield.Destroy()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for player in shields do Clear(player) end
end

return EnergyShield
