--!strict

return table.freeze({
	WeaponIds = table.freeze({ "AssaultRifle", "Shotgun", "Handgun" }),
	KeyBindings = table.freeze({
		[Enum.KeyCode.One] = "AssaultRifle",
		[Enum.KeyCode.Two] = "Shotgun",
		[Enum.KeyCode.Three] = "Handgun",
	}),
	RequestInterval = 0.2,
	SnapshotRetryInterval = 2,
})
