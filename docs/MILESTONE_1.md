# Milestone 1 — The Arena Slice

## What this milestone proves

That the three hardest technical bets in the design are sound, before any art
exists to make them expensive to change:

1. **Server-authoritative shooting can feel good.** Prediction on the client,
   truth on the server, one shared math module so they cannot disagree.
2. **Bullet-hell density is affordable.** Patterns replicate as a seed and a
   timestamp, not as projectiles. One remote call renders hundreds of bullets.
3. **Movement and bullet-hell coexist.** Slide, double jump, and dash are fast
   enough to feel like a Roblox movement shooter while still being validated.

It deliberately does **not** prove: persistence, PvP, mods, skills, the open
world, or anything requiring a published place.

## Mapping to the design document

| Scaffold phase | Status |
|---|---|
| Phase 1 — Combat prototype | Complete, expanded to five weapons |
| Phase 2 — Combat sandbox | Partial: enemies and dodge yes, PvP no |
| Phase 4 — Boss slice | Core complete: two phases, four patterns, wipe/reset |
| C1 Repository and toolchain | Complete |
| C2 Shared types, IDs, registries | Complete |
| C3 Bootstrap and lifecycle | Complete |
| C4 Networking layer | Complete |
| C5 Character and movement | Slide / double jump / dash; no mantle |
| C6 Weapon foundation | Hitscan complete; projectile weapons deferred |
| C7 Damage, health, status | Damage and health complete; statuses deferred |
| C11 Boss and bullet-pattern runtime | Complete except the debug visualiser |
| C18 Security and tests | Remote specs and pure-calculator specs in place |

## Architecture at a glance

```
CLIENT (presentation)                    SERVER (authority)
─────────────────────                    ──────────────────
InputController                          ServerBootstrap
   ↓ intent                                 ↓ deterministic init
WeaponController ──── C2S_FireWeapon ──→ WeaponService
   predicts recoil,                         rate limit → schema → equipped
   tracer, ammo, sound                      → ammo → cadence → origin
   THIS FRAME                               → cone → raycast → permission
   ↓                                        ↓
CameraController                          CombatService  ← the only path that
MovementController ── C2S_Movement ──→   MovementService    changes health
   predicts slide/dash                      cooldowns, grounding, i-frames
   ↓                                        ↓
ProjectileController ←─ S2C_PatternSpawn ─ BossService
   expands seed → hundreds                  expands the SAME seed,
   of pooled visuals                        hit-tests at 20 Hz
   ↓
DamageNumberController ← S2C_DamageDealt ─ (confirmed damage only)
```

The pure module `Shared/Combat/ProjectilePattern.luau` is evaluated on both
sides and reads nothing but its arguments. That is what makes the compact
replication safe.

## Known gaps and deliberate deferrals

These are choices, not oversights. Each has a reason.

| Gap | Why it was deferred |
|---|---|
| Persistence is in-memory | Half-finished save code loses player data. Needs versioned schemas, session locking, and idempotent transactions first (§C15). |
| No lag compensation | It only matters for PvP hitscan, and there is no PvP yet. Adding rewind now would be untestable. |
| Enemies are stepped primitives, not rigs | Rigs, animations, and navigation-ready geometry belong to the Studio workstream (§R8, §R11). Throwaway Humanoid rigs would generate physics bugs that teach us nothing. |
| Arena entry is a CFrame move, not a teleport | Reserved servers need published place IDs (§R1). The entry/exit flow is already shaped as a transaction, so swapping in `TeleportService` touches two functions. |
| No mods, skills, or stat calculator | Phase 3 in the roadmap. The trigger vocabulary and slot definitions are already in the weapon configs so the hooks exist. |
| `StreamingEnabled` is off | The world is generated at runtime in one place; streaming becomes meaningful when authored regions land (§4.4). |
| No audio | Sound asset IDs come from the Studio workstream (§R12). `AudioCue` names are already declared on every boss attack. |

## Suggested milestone 2

In priority order, each building directly on what exists:

1. **Mods and the stat calculator** (§C8) — the deterministic calculation order
   is documented and the slots are already in the weapon configs. This is the
   design's central pillar and nothing else blocks it.
2. **Status effects** (§C7) — thermal burn and arc chain give the damage-type
   vocabulary a reason to exist.
3. **Persistence** (§C15) — versioned profiles, session locking, idempotent
   rewards. Do this before any reward is worth having.
4. **Zones and the PvP gate** (§C12) — `CombatService:CanDamage` is already the
   single choke point; zones give it something to enforce.

## Verification

```bash
make check     # formatting, static analysis, clean build
make build     # then open build/BulletHell.rbxlx in Studio and press Play
```

In Studio, confirm:

- Output shows `[Bootstrap] 9 services started` and `[Tests] N passed`
- The hub, firing range, and arena generate with no warnings
- Distance markers on the range make falloff visible: the shotgun should fall
  off hard past 22 studs, the marksman rifle not at all
- Head shots on a dummy produce a larger, coloured number with a `✦` marker
- An SMG burst produces one merged number, not fourteen overlapping ones
- Sprint + `C` slides; the camera drops and speed carries
- `Q` dashes and the crosshair flashes cyan during the i-frame window
- Stepping on the purple pad starts the boss; conductors gate its damage
  reduction; dying to the pattern returns you to the hub and resets the arena
