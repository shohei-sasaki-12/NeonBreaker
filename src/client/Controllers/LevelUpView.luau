--!strict

local UpgradeConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("UpgradeConfig"))

export type Offer = {
	OfferId: number, Level: number, Candidates: { string }, Upgrades: { [string]: number },
}
export type View = {
	SetBusy: (boolean) -> (), Show: (Offer) -> (), Hide: () -> (), Destroy: () -> (),
}

local LevelUpView = {}

local function Label(parent: Instance, name: string, text: string, y: number, height: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.07, y)
	label.Size = UDim2.fromScale(0.86, height)
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = Color3.fromRGB(230, 245, 255)
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

function LevelUpView.Create(gui: ScreenGui, selectUpgrade: (string) -> ()): View
	local overlay = Instance.new("Frame")
	overlay.Name = "Choices"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(4, 8, 18)
	overlay.BackgroundTransparency = 0.3
	overlay.Active = true
	overlay.Parent = gui
	local heading = Label(overlay, "Heading", "LEVEL UP", 0.12, 0.09, 28)
	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.52)
	row.Size = UDim2.fromScale(0.92, 0.48)
	row.BackgroundTransparency = 1
	row.Parent = overlay
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1000, 340)
	limit.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local buttons: { TextButton } = {}
	local ids: { string } = {}
	local connections: { RBXScriptConnection } = {}
	for i = 1, UpgradeConfig.ChoiceCount do
		local card = Instance.new("TextButton")
		card.Name = "Card" .. i
		card.LayoutOrder = i
		card.Size = UDim2.fromScale(0.31, 1)
		card.BackgroundColor3 = Color3.fromRGB(15, 30, 48)
		card.Text = ""
		card.Modal = true
		card.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(50, 220, 240)
		stroke.Thickness = 2
		stroke.Parent = card
		Label(card, "UpgradeName", "", 0.08, 0.2, 22)
		Label(card, "Description", "", 0.31, 0.3, 16)
		Label(card, "Levels", "", 0.68, 0.2, 18)
		table.insert(buttons, card)
		table.insert(connections, card.Activated:Connect(function()
			local id = ids[i]
			if id then selectUpgrade(id) end
		end))
	end
	local view = {}
	function view.SetBusy(busy: boolean)
		heading.Text = if busy then "選択を送信中…" else "LEVEL UP — 強化を選択"
		for _, button in buttons do
			button.Interactable = not busy
			button.AutoButtonColor = not busy
		end
	end
	function view.Show(offer: Offer)
		ids = table.clone(offer.Candidates)
		for i, card in buttons do
			local id = ids[i]
			local definition = if id then UpgradeConfig.GetUpgradeConfig(id) else nil
			card.Visible = definition ~= nil
			if definition then
				local current = offer.Upgrades[id] or 0
				local nameLabel = card:FindFirstChild("UpgradeName") :: TextLabel
				local descriptionLabel = card:FindFirstChild("Description") :: TextLabel
				local levelsLabel = card:FindFirstChild("Levels") :: TextLabel
				nameLabel.Text = definition.DisplayName
				descriptionLabel.Text = definition.Description
				levelsLabel.Text = string.format("現在 Lv%d → 次 Lv%d", current, current + 1)
			end
		end
		view.SetBusy(false)
		gui.Enabled = true
	end
	function view.Hide()
		gui.Enabled = false
	end
	function view.Destroy()
		for _, connection in connections do connection:Disconnect() end
		overlay:Destroy()
		gui.Enabled = false
	end
	return view
end

return LevelUpView
