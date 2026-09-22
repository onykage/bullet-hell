--!strict
--[[
	Types/init.luau — shared type vocabulary.
	Keep every cross-boundary data shape here so the server, client, and config
	modules cannot drift.
]]

export type DamageType = "Kinetic" | "Explosive" | "Thermal" | "Arc" | "Corruption"

export type FireMode = "Auto" | "Semi" | "Burst"

export type WeaponStats = {
	Damage: number,
	FireRate: number, -- rounds per second
	MagazineSize: number,
	ReloadTime: number,
	SpreadDegrees: number, -- base hip-fire cone half-angle
	AimSpreadDegrees: number,
	SpreadPerShot: number,
	SpreadRecovery: number, -- degrees per second
	Range: number, -- studs at which falloff bottoms out
	FalloffStart: number,
	FalloffMinimum: number, -- damage multiplier at/after Range
	CriticalMultiplier: number,
	Pellets: number,
	RecoilVertical: number,
	RecoilHorizontal: number,
	AimFieldOfView: number,
	EquipTime: number,
}

export type WeaponDefinition = {
	Id: string,
	DisplayName: string,
	Family: string,
	Tags: { string },
	FireMode: FireMode,
	BurstCount: number?,
	DamageType: DamageType,
	BaseStats: WeaponStats,
	Slots: { [string]: number },
	Viewmodel: ViewmodelSpec,
}

-- Graybox viewmodel description. Replaced by a Studio-authored model once the
-- asset manifest lands; the shape of the spec is the handoff point.
export type ViewmodelSpec = {
	Color: Color3,
	BodySize: Vector3,
	BarrelSize: Vector3,
	BarrelOffset: Vector3,
	GripSize: Vector3,
	GripOffset: Vector3,
	HoldOffset: CFrame,
	AimOffset: CFrame,
}

export type DamageContext = {
	attackerUserId: number?,
	sourceId: string,
	weaponId: string?,
	damageType: DamageType,
	baseDamage: number,
	hitPosition: Vector3,
	hitRegion: string?,
	isCritical: boolean,
	isPvP: boolean,
	sequenceId: number,
}

export type DamageResult = {
	applied: number,
	remainingHealth: number,
	killed: boolean,
	isCritical: boolean,
	hitRegion: string?,
}

export type MovementAbility = "Slide" | "DoubleJump" | "Dash"

export type MovementState = {
	sliding: boolean,
	slideStartedAt: number,
	jumpsUsed: number,
	lastDashAt: number,
	lastSlideAt: number,
	grounded: boolean,
}

export type BossPhase =
	"Dormant"
	| "Preparing"
	| "Intro"
	| "PhaseOne"
	| "Transition"
	| "PhaseTwo"
	| "Enraged"
	| "Defeated"
	| "Rewards"
	| "Reset"

--[[
	A bullet pattern is described by data + a seed + a start timestamp, never by
	replicated per-frame transforms. Server and client both evaluate the same
	pure function over this record (see Combat/ProjectilePattern).
]]
export type PatternSpawn = {
	patternId: string,
	instanceId: number,
	seed: number,
	startTime: number, -- workspace:GetServerTimeNow() at spawn
	origin: CFrame,
	targetPosition: Vector3?,
	damage: number,
	damageType: DamageType,
}

export type PatternDefinition = {
	Id: string,
	Kind: "RadialWave" | "TargetedLine" | "Orbit" | "Spiral",
	Count: number,
	Speed: number,
	Lifetime: number,
	ProjectileRadius: number, -- damaging hit volume
	VisualRadius: number, -- drawn slightly larger than the hit volume
	TelegraphTime: number,
	Color: Color3,
	Damage: number,
	DamageType: DamageType,
	-- Kind-specific tuning
	GapCount: number?,
	GapWidthDegrees: number?,
	RotationSpeed: number?,
	Rings: number?,
	RingInterval: number?,
	OrbitRadius: number?,
	SpiralArms: number?,
}

return {}
