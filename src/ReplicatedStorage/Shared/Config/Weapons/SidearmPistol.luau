--!strict
-- Semi-auto sidearm: fast equip, rewards trigger discipline, no falloff cliff.
return {
	Id = "sidearm_pistol",
	DisplayName = "Marshal Sidearm",
	Family = "Pistol",
	Tags = { "Ballistic", "Sidearm" },
	FireMode = "Semi",
	DamageType = "Kinetic",

	BaseStats = {
		Damage = 29,
		FireRate = 5.5,
		MagazineSize = 12,
		ReloadTime = 1.5,
		SpreadDegrees = 1.6,
		AimSpreadDegrees = 0.18,
		SpreadPerShot = 0.55,
		SpreadRecovery = 7,
		Range = 260,
		FalloffStart = 70,
		FalloffMinimum = 0.5,
		CriticalMultiplier = 2.0,
		Pellets = 1,
		RecoilVertical = 1.5,
		RecoilHorizontal = 0.3,
		AimFieldOfView = 58,
		EquipTime = 0.2,
	},

	Slots = { Barrel = 1, Magazine = 1, Optic = 1, Core = 1 },

	Viewmodel = {
		Color = Color3.fromRGB(64, 68, 76),
		BodySize = Vector3.new(0.28, 0.42, 1.0),
		BarrelSize = Vector3.new(0.14, 0.14, 0.5),
		BarrelOffset = Vector3.new(0, 0.04, -0.7),
		GripSize = Vector3.new(0.24, 0.52, 0.3),
		GripOffset = Vector3.new(0, -0.42, 0.22),
		HoldOffset = CFrame.new(0.7, -0.68, -1.0),
		AimOffset = CFrame.new(0, -0.38, -0.85),
	},
}
