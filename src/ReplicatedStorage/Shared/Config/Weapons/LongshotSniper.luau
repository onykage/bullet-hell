--!strict
-- Marksman rifle: no falloff, heavy crit, punished for moving (see §9.2
-- "Gunsmith's Focus" — the skill hooks this weapon's aim-stability path).
return {
	Id = "longshot_sniper",
	DisplayName = "Longshot",
	Family = "MarksmanRifle",
	Tags = { "Ballistic", "Precision" },
	FireMode = "Semi",
	DamageType = "Kinetic",

	BaseStats = {
		Damage = 95,
		FireRate = 0.9,
		MagazineSize = 5,
		ReloadTime = 3.2,
		SpreadDegrees = 6.0, -- hip fire is deliberately useless
		AimSpreadDegrees = 0.02,
		SpreadPerShot = 1.4,
		SpreadRecovery = 3,
		Range = 1200,
		FalloffStart = 1200,
		FalloffMinimum = 1.0,
		CriticalMultiplier = 2.5,
		Pellets = 1,
		RecoilVertical = 5.5,
		RecoilHorizontal = 0.6,
		AimFieldOfView = 24,
		EquipTime = 0.6,
	},

	Slots = { Barrel = 1, Magazine = 1, Optic = 1, Core = 1 },

	Viewmodel = {
		Color = Color3.fromRGB(52, 58, 66),
		BodySize = Vector3.new(0.34, 0.44, 2.6),
		BarrelSize = Vector3.new(0.16, 0.16, 2.0),
		BarrelOffset = Vector3.new(0, 0.05, -2.2),
		GripSize = Vector3.new(0.28, 0.6, 0.36),
		GripOffset = Vector3.new(0, -0.5, 0.5),
		HoldOffset = CFrame.new(0.9, -0.76, -1.7),
		AimOffset = CFrame.new(0, -0.4, -1.3),
	},
}
