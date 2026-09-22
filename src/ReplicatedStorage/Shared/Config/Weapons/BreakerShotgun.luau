--!strict
-- Shotgun: tests spread, pellets, falloff, and close-range risk (§8.1).
return {
	Id = "breaker_shotgun",
	DisplayName = "Breaker",
	Family = "Shotgun",
	Tags = { "Ballistic", "Pellet" },
	FireMode = "Semi",
	DamageType = "Kinetic",

	BaseStats = {
		Damage = 11, -- per pellet; 9 pellets => 99 point-blank
		FireRate = 1.6,
		MagazineSize = 6,
		ReloadTime = 2.9,
		SpreadDegrees = 5.5,
		AimSpreadDegrees = 3.4,
		SpreadPerShot = 0,
		SpreadRecovery = 8,
		Range = 90,
		FalloffStart = 22,
		FalloffMinimum = 0.22,
		CriticalMultiplier = 1.25,
		Pellets = 9,
		RecoilVertical = 3.4,
		RecoilHorizontal = 0.9,
		AimFieldOfView = 62,
		EquipTime = 0.45,
	},

	Slots = { Barrel = 1, Magazine = 1, Optic = 1, Core = 1 },

	Viewmodel = {
		Color = Color3.fromRGB(112, 82, 58),
		BodySize = Vector3.new(0.4, 0.5, 2.2),
		BarrelSize = Vector3.new(0.26, 0.26, 1.5),
		BarrelOffset = Vector3.new(0, 0.06, -1.7),
		GripSize = Vector3.new(0.3, 0.62, 0.38),
		GripOffset = Vector3.new(0, -0.52, 0.4),
		HoldOffset = CFrame.new(0.88, -0.78, -1.5),
		AimOffset = CFrame.new(0, -0.45, -1.2),
	},
}
