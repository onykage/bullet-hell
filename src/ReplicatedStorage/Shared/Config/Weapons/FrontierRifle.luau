--!strict
-- Assault rifle: the baseline. Everything else is tuned relative to this.
return {
	Id = "frontier_rifle",
	DisplayName = "Frontier Rifle",
	Family = "AssaultRifle",
	Tags = { "Ballistic", "Automatic" },
	FireMode = "Auto",
	DamageType = "Kinetic",

	BaseStats = {
		Damage = 24,
		FireRate = 8,
		MagazineSize = 30,
		ReloadTime = 2.1,
		SpreadDegrees = 1.2,
		AimSpreadDegrees = 0.25,
		SpreadPerShot = 0.32,
		SpreadRecovery = 4.5,
		Range = 500,
		FalloffStart = 180,
		FalloffMinimum = 0.6,
		CriticalMultiplier = 1.5,
		Pellets = 1,
		RecoilVertical = 1.05,
		RecoilHorizontal = 0.42,
		AimFieldOfView = 55,
		EquipTime = 0.35,
	},

	Slots = { Barrel = 1, Magazine = 1, Optic = 1, Core = 1 },

	Viewmodel = {
		Color = Color3.fromRGB(86, 94, 104),
		BodySize = Vector3.new(0.35, 0.45, 2.0),
		BarrelSize = Vector3.new(0.18, 0.18, 1.3),
		BarrelOffset = Vector3.new(0, 0.05, -1.5),
		GripSize = Vector3.new(0.28, 0.6, 0.35),
		GripOffset = Vector3.new(0, -0.5, 0.35),
		HoldOffset = CFrame.new(0.85, -0.75, -1.4),
		AimOffset = CFrame.new(0, -0.42, -1.1),
	},
}
