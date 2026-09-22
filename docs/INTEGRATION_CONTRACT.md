# Integration Contract

**Generated from `src/ReplicatedStorage/Shared/Contract.luau`. Do not edit by hand —
run `make contract`.**

This is the complete set of names shared between the code workstream and the
Roblox Studio workstream. Changing any value here is a contract change: update
the module, regenerate this file, tell the other workstream, and re-run the
affected integration milestone (design doc, *Change-control rule*).

## Tagged Instances

Every tagged gameplay object also carries a stable `ContentId` attribute that is
never reused for different content.

| Purpose | CollectionService tag | Required attributes |
|---|---|---|
| Zone | `GameZone` | `ZoneId` |
| Player Spawn | `PlayerSpawn` | `SpawnId`, `SpawnType` |
| Enemy Spawn Volume | `EnemySpawnVolume` | `EncounterId`, `SpawnGroup` |
| Arena Entrance | `ArenaEntrance` | `ArenaId` |
| Boss Marker | `BossMarker` | `ArenaId`, `MarkerId` |
| Attack Origin | `AttackOrigin` | `ArenaId`, `MarkerId` |
| Interactable | `Interactable` | `InteractionId`, `InteractionType` |
| Extraction Point | `ExtractionPoint` | `ZoneId`, `ExtractionId` |
| Safe Zone Barrier | `SafeZoneBarrier` | `ZoneId` |
| Navigation Hint | `NavigationHint` | `HintType`, `GroupId` |
| Weak Point | `WeakPoint` | `RegionId`, `DamageMultiplier` |
| Hit Region | `HitRegion` | `RegionId`, `DamageMultiplier` |
| Conductor | `BossConductor` | `ArenaId`, `MarkerId` |

## Required Workspace containers

These Folders must exist and keep these names. The code creates any that are
missing at boot, so an empty place still runs, but authored content must live
in the right one to be found.

| Container | Holds |
|---|---|
| `World` | All authored world geometry |
| `ArenaEntrances` | Arena entrance landmarks |
| `SpawnVolumes` | Enemy spawn volumes |
| `ZoneVolumes` | Zone rule volumes |
| `EncounterMarkers` | Boss spawns, attack origins, conductors, arena spawns |
| `NavigationMarkers` | Jump links, cover hints, restricted paths |
| `Interactables` | Vendors, pickups, prompts |
| `Runtime` | Code-owned, never authored, never saved |

## Collision groups

Registered by `CollisionGroupService` at boot, so the place file and the code
cannot disagree about which groups exist.

| Group | Notes |
|---|---|
| `Default` |  |
| `Player` | Players do not collide with each other |
| `Enemy` | Enemies do not collide with each other |
| `Projectile` | Cosmetic only — collides with nothing |
| `Viewmodel` | First-person weapon; never collides or blocks a ray |
| `WorldProp` | Static authored geometry |
| `SafeZoneBarrierGroup` | Blocks damage in both directions |
| `Debris` | Short-lived physical effects |

## Weapon model attachments

Every weapon model supplied by the Studio workstream needs these attachment
points, spelled exactly like this.

| Attachment | Purpose |
|---|---|
| `Muzzle` | Tracer origin, muzzle flash |
| `AimPoint` | Aligned to screen centre when aiming |
| `LeftHandGrip` | Off-hand IK target |
| `Magazine` | Reload animation detach point |
| `CasingEject` | Shell ejection origin |

## Storm Engine arena markers

Parts tagged `BossMarker` or `AttackOrigin` with `ArenaId = "storm_engine_arena"`
and the `MarkerId` values below. The code looks markers up by tag and attribute,
never by path, so generated and authored geometry are interchangeable.

| MarkerId | Purpose |
|---|---|
| `BossSpawn` | Where the boss is placed and where self-centred patterns originate |
| `PlayerSpawn` | Party arrival points (also needs `SpawnType = "Arena"`) |
| `ArenaCenter` | Reference point for arena-relative logic |
| `ReturnPoint` | Where players are sent on completion or wipe |

Additionally: `AttackOrigin1`–`AttackOrigin4` (tag `AttackOrigin`) and
`Conductor1`–`Conductor4` (tag `BossConductor`).

## How to replace the graybox

`WorldBuilderService` generates the blockout **only** when `Workspace.World` is
empty. Commit authored geometry into that container with these tags and
attributes and the generator stops on its own — no flag to flip, no code change.
Set the `GrayboxDisabled` attribute on `Workspace` to force it off regardless.
