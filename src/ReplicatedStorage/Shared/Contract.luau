--!strict
--[[
	Contract.luau

	The single source of truth for every name shared between the code workstream
	and the Roblox Studio workstream (see docs/design §R5 and "Integration
	Contract Between Teams").

	RULE: nothing in this codebase may hard-code one of these strings inline.
	Changing a value here is a contract change and requires notifying the Studio
	workstream and re-running the affected integration milestone.
]]

local Contract = {}

-- CollectionService tags applied to authored (or graybox-generated) Instances.
Contract.Tags = {
	Zone = "GameZone",
	PlayerSpawn = "PlayerSpawn",
	EnemySpawnVolume = "EnemySpawnVolume",
	ArenaEntrance = "ArenaEntrance",
	BossMarker = "BossMarker",
	AttackOrigin = "AttackOrigin",
	Interactable = "Interactable",
	ExtractionPoint = "ExtractionPoint",
	SafeZoneBarrier = "SafeZoneBarrier",
	NavigationHint = "NavigationHint",

	-- Combat-surface tags
	WeakPoint = "WeakPoint",
	HitRegion = "HitRegion",
	Conductor = "BossConductor",
}

-- Attribute names expected on tagged Instances, keyed by tag.
Contract.Attributes = {
	[Contract.Tags.Zone] = { "ZoneId" },
	[Contract.Tags.PlayerSpawn] = { "SpawnId", "SpawnType" },
	[Contract.Tags.EnemySpawnVolume] = { "EncounterId", "SpawnGroup" },
	[Contract.Tags.ArenaEntrance] = { "ArenaId" },
	[Contract.Tags.BossMarker] = { "ArenaId", "MarkerId" },
	[Contract.Tags.AttackOrigin] = { "ArenaId", "MarkerId" },
	[Contract.Tags.Interactable] = { "InteractionId", "InteractionType" },
	[Contract.Tags.ExtractionPoint] = { "ZoneId", "ExtractionId" },
	[Contract.Tags.SafeZoneBarrier] = { "ZoneId" },
	[Contract.Tags.NavigationHint] = { "HintType", "GroupId" },
	[Contract.Tags.WeakPoint] = { "RegionId", "DamageMultiplier" },
	[Contract.Tags.HitRegion] = { "RegionId", "DamageMultiplier" },
	[Contract.Tags.Conductor] = { "ArenaId", "MarkerId" },
}

-- Every authored gameplay object carries a stable, never-reused identifier.
Contract.ContentIdAttribute = "ContentId"

-- Required Workspace containers. WorldBuilder creates these when missing so a
-- blank place still boots; the Studio workstream owns them once geometry lands.
Contract.Containers = {
	World = "World",
	ArenaEntrances = "ArenaEntrances",
	SpawnVolumes = "SpawnVolumes",
	ZoneVolumes = "ZoneVolumes",
	EncounterMarkers = "EncounterMarkers",
	NavigationMarkers = "NavigationMarkers",
	Interactables = "Interactables",
	Runtime = "Runtime", -- non-authored, code-owned, never saved
}

-- Collision groups. Registered by CollisionService at boot.
Contract.CollisionGroups = {
	Default = "Default",
	Player = "Player",
	Enemy = "Enemy",
	Projectile = "Projectile",
	Viewmodel = "Viewmodel",
	WorldProp = "WorldProp",
	SafeZoneBarrier = "SafeZoneBarrierGroup",
	Debris = "Debris",
}

-- Model attachment names the Studio workstream must provide on weapon models.
Contract.WeaponAttachments = {
	Muzzle = "Muzzle",
	AimPoint = "AimPoint",
	LeftHandGrip = "LeftHandGrip",
	Magazine = "Magazine",
	CasingEject = "CasingEject",
}

-- Boss arena marker IDs for the Storm Engine slice.
Contract.Markers = {
	BossSpawn = "BossSpawn",
	PlayerSpawn = "PlayerSpawn",
	ArenaCenter = "ArenaCenter",
	ReturnPoint = "ReturnPoint",
}

--[[
	Returns (ok, reason). Used by validators at startup so malformed authored
	content fails loudly in development instead of misbehaving at runtime.
]]
function Contract.validateInstance(instance: Instance, tag: string): (boolean, string?)
	local required = Contract.Attributes[tag]
	if not required then
		return false, string.format("Unknown tag %q", tag)
	end

	if instance:GetAttribute(Contract.ContentIdAttribute) == nil then
		return false,
			string.format(
				"%s is tagged %q but has no %s attribute",
				instance:GetFullName(),
				tag,
				Contract.ContentIdAttribute
			)
	end

	for _, attribute in required do
		if instance:GetAttribute(attribute) == nil then
			return false,
				string.format(
					"%s is tagged %q but is missing attribute %q",
					instance:GetFullName(),
					tag,
					attribute
				)
		end
	end

	return true, nil
end

table.freeze(Contract)
return Contract
