--!strict
-- SMG: highest ROF, lowest per-shot damage, punishing bloom past short range.
return {
	Id = "ripper_smg",
	DisplayName = "Ripper",
	Family = "SMG",
	Tags = { "Ballistic", "Automatic", "CloseQuarters" },
	FireMode = "Auto",
	DamageType = "Kinetic",

	BaseStats = {
		Damage = 14,
		FireRate = 14,
		MagazineSize = 40,
		ReloadTime = 1.9,
		SpreadDegrees = 2.4,
		AimSpreadDegrees = 1.1,
		SpreadPerShot = 0.34,
		SpreadRecovery = 6,
		Range = 180,
		FalloffStart = 45,
		FalloffMinimum = 0.42,
		CriticalMultiplier = 1.35,
		Pellets = 1,
		RecoilVertical = 0.72,
		RecoilHorizontal = 0.55,
		AimFieldOfView = 62,
		EquipTime = 0.28,
	},

	Slots = { Barrel = 1, Magazine = 1, Optic = 1, Core = 1 },

	Viewmodel = {
		Color = Color3.fromRGB(58, 100, 96),
		BodySize = Vector3.new(0.32, 0.42, 1.4),
		BarrelSize = Vector3.new(0.15, 0.15, 0.7),
		BarrelOffset = Vector3.new(0, 0.04, -1.0),
		GripSize = Vector3.new(0.26, 0.58, 0.32),
		GripOffset = Vector3.new(0, -0.46, 0.28),
		HoldOffset = CFrame.new(0.8, -0.72, -1.2),
		AimOffset = CFrame.new(0, -0.4, -1.0),
	},
}
