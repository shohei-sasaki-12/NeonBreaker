--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EMPConfig"))
local PlayerStateService = require(script.Parent.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

type EnemyQuery = (Vector3, number) -> { Model }
type EMPHandler = (Model) -> boolean
local queryEnemies: EnemyQuery? = nil
local applyEMP: EMPHandler? = nil
local effectsRemote: RemoteEvent? = nil
local EMPPulse = {}

function EMPPulse.Use(player: Player, _level: number, _direction: Vector3)
	assert(RunService:IsServer() and queryEnemies and applyEMP, "EMPPulse must be initialized on the server")
	local state = PlayerStateService.GetState(player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	assert(state and state.CurrentSpecial == "EMPPulse" and character and character.Parent
		and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0, "EMPPulse requires a living owner")
	local position = root.Position -- Never accept a center, radius or target list from clients.
	local query = queryEnemies :: EnemyQuery
	local apply = applyEMP :: EMPHandler
	local affected: { [Model]: boolean } = {}
	for _, enemy in query(position, Config.Radius) do
		local enemyRoot = enemy.PrimaryPart
		if not affected[enemy] and enemyRoot and (enemyRoot.Position - position).Magnitude <= Config.Radius then
			affected[enemy] = true
			apply(enemy)
		end
	end
	if effectsRemote then
		effectsRemote:FireAllClients({ SpecialId = "EMPPulse", Event = "Pulsed", Position = position, Radius = Config.Radius })
	end
end

function EMPPulse.Init(query: EnemyQuery, handler: EMPHandler)
	if queryEnemies then return end
	assert(RunService:IsServer(), "EMPPulse must run on the server")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Effects"):WaitForChild("PlaySpecialEffect")
	assert(remote:IsA("RemoteEvent"), "EMPPulse effects remote is missing")
	queryEnemies = query
	applyEMP = handler
	effectsRemote = remote
end

function EMPPulse.Destroy()
	queryEnemies = nil
	applyEMP = nil
	effectsRemote = nil
end

return EMPPulse
