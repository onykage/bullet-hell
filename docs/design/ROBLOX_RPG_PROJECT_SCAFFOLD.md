# Roblox Open-World Bullet-Hell FPS RPG

## Complete Project Scaffold

**Working document:** Preproduction and technical architecture  
**Platform:** Roblox  
**Genre:** Open-world FPS RPG / bullet hell / PvPvE  
**Primary mode:** Cooperative PvE with structured open-world PvP  
**Recommended initial party size:** 1–4 players  
**Document status:** Foundation for prototyping and production planning

---

## Table of Contents

1. [High Concept](#1-high-concept)
2. [Design Pillars](#2-design-pillars)
3. [Player Experience](#3-player-experience)
4. [World Structure](#4-world-structure)
5. [PvE Combat](#5-pve-combat)
6. [Open-World PvP](#6-open-world-pvp)
7. [Bosses and Arenas](#7-bosses-and-arenas)
8. [Weapons and Gun Modification](#8-weapons-and-gun-modification)
9. [Skills and Character Progression](#9-skills-and-character-progression)
10. [Items, Economy, and Rewards](#10-items-economy-and-rewards)
11. [Quests, Events, and Social Systems](#11-quests-events-and-social-systems)
12. [Technical Architecture](#12-technical-architecture)
13. [Recommended Project Structure](#13-recommended-project-structure)
    - [Code Workstream](#code-workstream-your-team)
    - [Roblox Studio Workstream](#roblox-studio-workstream-other-team)
    - [Integration Contract](#integration-contract-between-teams)
14. [Core Data Models](#14-core-data-models)
15. [Networking and Security](#15-networking-and-security)
16. [Performance Strategy](#16-performance-strategy)
17. [UI and Player Feedback](#17-ui-and-player-feedback)
18. [Development Roadmap](#18-development-roadmap)
19. [Vertical Slice Specification](#19-vertical-slice-specification)
20. [Testing and Acceptance Criteria](#20-testing-and-acceptance-criteria)
21. [Team Roles and Workflow](#21-team-roles-and-workflow)
22. [Major Risks and Guardrails](#22-major-risks-and-guardrails)
23. [Launch and Post-Launch Direction](#23-launch-and-post-launch-direction)
24. [Production Checklists](#24-production-checklists)

---

## 1. High Concept

An open-world Roblox FPS RPG where players explore dangerous regions, fight enemy factions, discover boss arenas, and create specialized firearms through modular parts and gunsmithing skills. Safe settlements separate progressively more dangerous frontier and contested zones. Players may cooperate against enemies and world bosses or compete for valuable objectives in PvP-enabled regions.

The game should combine:

- Responsive first-person shooting
- Readable bullet-hell movement and dodging
- Build-defining gun modifications
- RPG progression without excessive stat inflation
- Memorable boss arenas embedded in the world
- Purposeful PvP driven by objectives, territory, and valuable resources
- A world that rewards exploration rather than simply following map markers

### Player fantasy

> Enter a hostile frontier, build a weapon that behaves like no one else's, master impossible projectile patterns, defeat enormous bosses, and survive rival players long enough to bring the rewards home.

### Target session shapes

| Session | Intended activity |
|---|---|
| 10–15 minutes | Complete a contract, modify a weapon, join a nearby event |
| 20–30 minutes | Explore a region, clear an encounter, challenge a minor boss |
| 30–60 minutes | Run a major arena, enter a contested zone, complete an extraction loop |
| Long session | Group progression, multiple objectives, boss farming, PvP territory play |

---

## 2. Design Pillars

### 2.1 Weapons are builds

A gun is a platform, not a finished item. Barrels, magazines, optics, cores, ammunition effects, and gunsmithing skills should alter its behavior and tactical role.

### 2.2 Dense combat remains readable

Bullet patterns must communicate danger clearly. Telegraphs, colors, sounds, timing, and consistent collision rules matter more than filling the screen with projectiles.

### 2.3 The world creates stories

Players should see distant landmarks, discover entrances, encounter roaming threats, and make risk-versus-reward decisions without every activity feeling like a menu queue.

### 2.4 PvP has a purpose

Players fight over objectives, valuable resources, bounties, and extraction—not solely for random kills. Safe progression remains available outside forced-PvP zones.

### 2.5 Skill beats raw power

Equipment matters, but aiming, movement, positioning, pattern recognition, and teamwork must remain decisive. Progression should broaden build options more than it increases absolute power.

### 2.6 Fairness is visible

Players should understand why they took damage, which areas permit PvP, what they risk losing, and what an enemy build broadly does.

---

## 3. Player Experience

### 3.1 Primary loop

```text
Prepare at hub
    ↓
Choose loadout, skills, and objective
    ↓
Explore the open world
    ↓
Fight enemies / complete events / encounter players
    ↓
Find loot, mods, materials, and arena access
    ↓
Challenge a boss or enter a contested objective
    ↓
Extract or return safely
    ↓
Bank rewards, craft, modify, and specialize
    ↓
Enter a harder region
```

### 3.2 Long-term loop

- Discover weapon families and modification recipes.
- Unlock gunsmithing skills that change build rules.
- Defeat regional bosses to gain access to new biomes.
- Improve faction reputation and settlement services.
- Collect cosmetics, titles, blueprints, and boss trophies.
- Master difficult arena variants and contested endgame events.

### 3.3 Moment-to-moment combat loop

```text
Read threat → move or dodge → aim → fire → trigger build effects
→ manage ammunition/heat → reposition → exploit opening → recover
```

### 3.4 Death and recovery

Recommended default:

- Equipped weapons and permanent mods are never dropped.
- Normal PvE death causes durability or temporary resource loss, not item deletion.
- Contested zones place a clearly identified portion of newly acquired materials at risk.
- Unbanked contested loot can be lost, partially recovered, or claimed by opponents.
- Main-story items, premium items, and irreplaceable rewards can never be lost.
- Players respawn away from their killer and receive brief protection.

---

## 4. World Structure

Build the world as connected regions rather than one enormous uniform map.

```text
Central Settlement
├── Training Grounds
├── Frontier Region A
│   ├── Public events
│   ├── Minor arena
│   └── Major PvE arena
├── Industrial Region B
│   ├── Faction outposts
│   ├── Contested resource sites
│   └── Machinery boss
├── Corrupted Region C
│   ├── Dense bullet-hell encounters
│   ├── Extraction route
│   └── Projectile boss
└── Endgame Region
    ├── Rotating world events
    ├── High-risk PvPvE zone
    └── Raid-scale arena
```

### 4.1 Zone types

| Zone | PvP rule | Purpose | Reward level |
|---|---|---|---|
| Sanctuary | Disabled | Hub, vendors, social space, crafting | None/low |
| Civilized | Disabled | Story, tutorials, relaxed exploration | Low/moderate |
| Frontier | Optional or event-based | Mixed exploration and opt-in PvP | Moderate |
| Contested | Always enabled | Objectives, rare materials, extraction | High |
| Arena | Defined per encounter | Bosses and competitive modes | Encounter-specific |

### 4.2 Region template

Every region should contain:

- One visually dominant landmark
- One settlement, camp, or recovery point
- Two or three enemy archetypes
- One faction presence
- Three exploration discoveries
- Two repeatable public events
- One minor arena
- One major boss arena or world boss
- One region-specific material
- One traversal feature
- At least one route that rewards players who leave the main road

### 4.3 Arena discovery

Arenas should exist as physical landmarks. Doors, elevators, portals, tunnels, or ritual sites can move players into an isolated server while preserving the sense that the arena belongs to the open world.

### 4.4 Streaming

- Enable world streaming early in development.
- Divide geometry, AI spawns, effects, and audio into region-based packages.
- Keep critical interaction and collision objects reliably streamed.
- Test traversal at maximum supported movement speed.
- Never assume every client has the full world loaded.

---

## 5. PvE Combat

### 5.1 Combat principles

- Enemies telegraph dangerous attacks.
- Incoming damage has a readable source.
- Movement creates survivability but does not make players permanently untouchable.
- Enemy health does not become a substitute for encounter design.
- Different builds receive opportunities to shine.
- Crowd control uses diminishing returns or resistance on elite enemies.

### 5.2 Recommended player actions

- Walk, sprint, jump, crouch, and mantle
- Aim down sights
- Hip fire
- Reload or active reload
- Dodge/dash with a visible cooldown or stamina cost
- Use one tactical ability
- Use one build-defining skill or ultimate
- Interact, revive, and ping

Avoid adding excessive movement systems before basic shooting and encounter readability are proven.

### 5.3 Enemy roles

| Role | Purpose |
|---|---|
| Grunt | Establishes baseline pressure and ammunition rhythm |
| Rusher | Forces movement and target prioritization |
| Marksman | Punishes standing still and exposes sight lines |
| Artillery | Creates persistent area denial |
| Support | Shields, heals, buffs, or summons allies |
| Controller | Applies slows, traps, knockback, or forced positioning |
| Elite | Combines mechanics and drops better rewards |

### 5.4 Damage vocabulary

Start with a small set:

- Kinetic: dependable direct damage
- Explosive: area damage and stagger
- Thermal: damage over time and armor interaction
- Arc: chaining and shield disruption
- Corruption: debuffs and risk/reward mechanics

Every additional damage type increases UI, balance, enemy, and item complexity. Add one only when it enables distinct play.

---

## 6. Open-World PvP

### 6.1 Recommended PvP model

Use a hybrid system:

- PvP is disabled in sanctuaries and standard story areas.
- Frontier PvP is opt-in or activated around public objectives.
- Contested regions use always-on PvP with explicit entry warnings.
- Major story bosses remain accessible through protected PvE instances.
- High-risk PvPvE encounters offer better or faster rewards, not exclusive character power.

This keeps PvP meaningful without allowing stronger players to block normal progression.

### 6.2 PvP objectives

- Capture and hold outposts
- Intercept supply convoys
- Recover and extract artifacts
- Hunt high-value roaming enemies
- Claim temporary resource sites
- Complete player bounties
- Fight contested world bosses
- Escort faction transports

### 6.3 PvP eligibility rules

Before applying player damage, validate:

- Both players are in compatible PvP states.
- The attack originated in a legal zone.
- Neither player has active spawn or transition protection.
- Team, party, and faction rules allow damage.
- The attacker is alive and has the weapon equipped.
- The target is not behind a safe-zone boundary.
- A duel, event, or arena has not ended.

### 6.4 Anti-griefing rules

- Spawn protection ends early if the protected player attacks.
- Safe-zone barriers block damage in both directions.
- Repeated kills against the same victim stop granting rewards.
- Respawns occur away from recent attackers.
- Low-level progression routes do not cross forced-PvP territory.
- Combat logging applies a short in-world persistence or forfeiture penalty.
- Kill credit includes assists and contribution.
- Solo activities monitor organized cross-team cooperation where relevant.
- Death screens clearly identify the weapon, damage source, and major build effect.

### 6.5 PvP scaling

Separate PvE and PvP tuning without changing the weapon's identity.

Tune independently:

- Damage multiplier
- Critical-hit multiplier
- Healing and lifesteal
- Stagger and knockback
- Status duration
- Homing strength
- Explosive radius
- Ability and ultimate gain

Do not promise perfectly equal equipment in the open world. Instead, constrain power gaps, use gear bands where necessary, and preserve counterplay.

### 6.6 PvP rewards

Prefer horizontal and prestige rewards:

- Alternate mod sidegrades
- Crafting materials
- Cosmetics and weapon finishes
- Faction reputation
- Titles, banners, and trophies
- Faster access to resources also available through PvE

Avoid rewards that make winners increasingly unbeatable.

---

## 7. Bosses and Arenas

### 7.1 Arena categories

| Type | Description | Recommended use |
|---|---|---|
| Instanced PvE | Private party encounter | Story and core progression |
| Public PvE | Shared encounter in the world | Community events |
| Contested world boss | Boss and PvP active together | High-risk endgame rewards |
| Competitive arena | Teams race mirrored encounters | Fairer PvPvE competition |
| Invasion arena | Opponent enters an active encounter | Optional late-game mode |

### 7.2 Boss state machine

```text
Dormant
→ Preparing
→ Intro
→ PhaseOne
→ Transition
→ PhaseTwo
→ Enraged
→ Defeated
→ Rewards
→ Reset
```

The server owns the state, timing, valid targets, health, phase changes, and result.

### 7.3 Attack module contract

Each boss attack should define:

- Attack identifier
- Valid phases
- Telegraph duration
- Execution duration
- Recovery duration
- Cooldown and selection weight
- Targeting rule
- Pattern or hit-volume definition
- Damage and status effects
- Interrupt and cancellation rules
- Required arena markers
- Audio and visual cues

### 7.4 Bullet-hell readability

- Reserve consistent colors for friendly, hostile, unblockable, and environmental effects.
- Give major attacks distinct audio cues.
- Telegraph before damage becomes active.
- Make visual projectiles slightly larger than their damaging hit volumes.
- Avoid patterns that depend on perfect latency.
- Provide low-effects settings without hiding gameplay information.
- Test encounters on mobile screens and lower-performance devices.

### 7.5 Boss design matrix

Each boss should test one primary skill and one secondary skill.

| Boss concept | Primary test | Secondary test |
|---|---|---|
| Mobile hunter | Tracking | Repositioning |
| Armored colossus | Weak-point accuracy | Stagger timing |
| Swarm host | Crowd control | Resource management |
| Storm engine | Pattern reading | Sustained damage |
| Regenerator | Burst windows | Target prioritization |
| Arena architect | Spatial awareness | Team coordination |

### 7.6 Reward contribution

For shared encounters, score meaningful participation:

- Boss and objective damage
- Healing, shielding, and revives
- Mechanical objectives completed
- Adds controlled or defeated
- Time actively participating
- PvP contribution during contested encounters

Never award an entire boss solely to the last hit.

---

## 8. Weapons and Gun Modification

### 8.1 Initial weapon families

Begin with two and expand only after the framework is stable:

1. Assault rifle: versatile, consistent, easy to evaluate.
2. Shotgun: immediately tests spread, falloff, pellets, burst damage, and close-range risk.

Later families may include pistols, marksman rifles, launchers, beam weapons, and support weapons.

### 8.2 Suggested mod slots

- Barrel
- Magazine
- Optic
- Stock or grip
- Core
- Ammunition

The vertical slice needs only four active slot types. Additional slots should wait until each creates an interesting choice.

### 8.3 Modifier philosophy

A mod should do at least one of the following:

- Change how the player uses the weapon.
- Create a meaningful tradeoff.
- Enable a synergy.
- Solve a specific combat problem.
- Introduce a trigger the player can deliberately activate.

Avoid upgrades that are merely “+5% damage” unless they support a broader crafting or progression purpose.

### 8.4 Example mods

| Mod | Benefit | Cost |
|---|---|---|
| Heavy Barrel | Better range and penetration | Slower aim movement |
| Explosive Core | Hits create small blasts | Lower direct-hit damage |
| Tracking Rounds | Slight projectile guidance | Slower projectile and visible trail |
| High-Caliber Magazine | Strong armor damage | Smaller magazine |
| Suppressor | Reduced detection | Reduced effective range |
| Ricochet Core | Shots rebound once | Reduced first-hit damage |

### 8.5 Final stat calculation order

Use one deterministic order:

```text
Base weapon values
→ flat additions
→ additive percentages
→ multiplicative modifiers
→ mode-specific PvE/PvP values
→ minimums, maximums, and hard caps
→ temporary buffs and debuffs
→ final validated runtime stats
```

Cache calculated builds and recalculate only when equipment, skills, or persistent effects change.

### 8.6 Trigger vocabulary

- `OnEquip`
- `OnFire`
- `OnProjectileCreated`
- `OnHit`
- `OnWeakPointHit`
- `OnCriticalHit`
- `OnKill`
- `OnReloadStart`
- `OnReloadComplete`
- `OnMagazineEmpty`
- `OnDamageTaken`
- `OnDodge`

Effects should subscribe to a controlled trigger system rather than embedding special-case logic in the weapon controller.

### 8.7 Compatibility controls

Every mod should include:

- Allowed slot
- Compatible weapon tags
- Incompatible mod tags
- Stack policy
- Power budget or rarity
- PvP restrictions, if any
- Effect parameters within server-enforced bounds

---

## 9. Skills and Character Progression

### 9.1 Progression layers

| Layer | Function |
|---|---|
| Account | Cosmetics, convenience unlocks, broad milestones |
| Character | Region access, core abilities, reputation |
| Weapon mastery | Family-specific handling and sidegrades |
| Gunsmithing | Modification rules and build synergies |
| Temporary run state | Short-lived event or zone bonuses |

### 9.2 Gunsmithing skill examples

- **Overclock:** Sustained fire increases rate of fire and heat.
- **Rechamber:** The last round deals bonus stagger damage.
- **Jury Rig:** Equip one off-slot mod at reduced effectiveness.
- **Elemental Routing:** Matching elemental tags unlocks a secondary effect.
- **Salvager:** Dismantling a rare weapon may preserve one attached mod.
- **Gunsmith's Focus:** Accuracy improves while aiming without moving.
- **Emergency Feed:** Dodging during an empty reload restores a few rounds.
- **Controlled Failure:** Overheating creates a short shockwave but disables firing briefly.

### 9.3 Skill-tree rules

- Early choices teach mechanics rather than demand perfect builds.
- Respecs should be accessible enough to encourage experimentation.
- Major nodes change behavior; minor nodes support that behavior.
- No skill should be mandatory for every build.
- PvP tooltips must show PvP-specific behavior.
- Character level should not create insurmountable PvP health differences.

---

## 10. Items, Economy, and Rewards

### 10.1 Item categories

- Weapon platforms
- Mods
- Crafting materials
- Consumables
- Quest items
- Cosmetics
- Blueprints
- Arena keys or access items
- Unbanked contested-zone resources

### 10.2 Rarity

Rarity should describe complexity or scarcity, not automatically invalidate lower-rarity equipment.

Suggested tiers:

- Common
- Field
- Specialist
- Prototype
- Boss

Named boss mods should offer distinctive mechanics rather than universally larger numbers.

### 10.3 Currency separation

Keep the initial economy simple:

- Credits: general vendors and basic services
- Components: crafting and modification
- Boss tokens: deterministic encounter rewards
- Faction marks: reputation stores

Avoid launching with numerous currencies that differ only in name.

### 10.4 Economy sinks

- Crafting
- Mod rerouting or recalibration
- Cosmetic unlocks
- Optional repair or maintenance
- Travel convenience
- Blueprint research

Do not rely on destructive item loss as the only economy sink.

### 10.5 Monetization guardrails

If monetized, prefer:

- Cosmetics
- Animation and sound packages
- Additional loadout slots
- Noncompetitive social features
- Convenience that does not alter combat outcomes

Avoid selling direct PvP power, exclusive best-in-slot weapons, or paid protection from normal loss rules.

---

## 11. Quests, Events, and Social Systems

### 11.1 Quest types

- Main regional story
- Faction contracts
- Gunsmith challenges
- Boss investigations
- Exploration discoveries
- PvP bounties
- Rotating public events

### 11.2 Public-event structure

```text
World warning
→ Gathering window
→ Main objective
→ Escalation based on participation
→ Success/failure state
→ Contribution-based rewards
→ Cooldown and world-state change
```

### 11.3 Party features

- Invite, leave, and promote leader
- Shared waypoint and pings
- Party-friendly-fire rules
- Arena readiness check
- Rejoin window after disconnect
- Contribution-based loot rather than manual loot competition

### 11.4 Factions

Factions can provide narrative and PvP structure, but permanent faction selection should not divide friends too early. Begin with reputation tracks; consider hard allegiance only after player behavior proves it valuable.

---

## 12. Technical Architecture

### 12.1 Authority model

The client provides responsiveness and presentation. The server provides truth.

| Client owns | Server owns |
|---|---|
| Input collection | Damage and health |
| Camera and recoil presentation | Ammo validation |
| Local animations and audio | Fire-rate validation |
| Crosshair and immediate feedback | Equipment and build validation |
| Cosmetic tracers and particles | Enemy and boss state |
| Predicted hit indicators | PvP eligibility |
| UI | Rewards and persistence |

Client prediction may improve feel, but the client cannot award damage, items, currency, or progression.

### 12.2 Service responsibilities

| Service | Responsibility |
|---|---|
| PlayerDataService | Profiles, migration, session locking, save lifecycle |
| CombatService | Damage calculation, health, statuses, combat events |
| WeaponService | Equip, reload, fire validation, final build snapshots |
| ModService | Compatibility, installation, removal, stat composition |
| SkillService | Unlocks, loadouts, trigger effects |
| EnemyService | Enemy lifecycle and behavior coordination |
| BossService | Boss state machines and encounter results |
| ArenaService | Entry, party transfer, reset, completion |
| PvPService | Damage permission, teams, protection, combat state |
| ZoneService | Zone membership and rule lookup |
| LootService | Drop generation and ownership |
| RewardService | Contribution and reward resolution |
| QuestService | Objective tracking and quest state |
| WorldService | Events, spawners, region state |
| FactionService | Reputation, alignment, faction objectives |
| BountyService | Bounty creation, eligibility, payout |
| AntiAbuseService | Rate limits, impossible-state detection, audit signals |
| MatchmakingService | Parties, reserved arenas, competitive queues |

### 12.3 Controller responsibilities

| Controller | Responsibility |
|---|---|
| InputController | Input mapping across keyboard, gamepad, and touch |
| CameraController | First-person camera, recoil, shake, FOV |
| WeaponController | Predicted firing, reload presentation, viewmodel |
| MovementController | Sprint, crouch, dodge, mantle requests |
| EffectsController | Tracers, impacts, projectiles, status visuals |
| AudioController | Spatial and interface sound playback |
| UIController | HUD and screen lifecycle |
| InteractionController | Prompts, loot, vendors, objectives |
| ZoneController | Local zone presentation and warnings |

### 12.4 Event flow: firing a weapon

```text
Player presses fire
→ Client verifies local predicted state
→ Client immediately plays recoil, animation, sound, and tracer
→ Client sends shot request with sequence, origin, direction, and time
→ Server rate-limits request
→ Server validates player, weapon, ammo, cadence, origin, and direction
→ Server resolves hit using authoritative rules and limited lag compensation
→ Server asks PvPService whether player damage is legal
→ Server applies damage and effects
→ Server replicates confirmed result
→ Client reconciles hit marker, ammo, and effects
```

### 12.5 Event flow: entering an arena

```text
Party interacts with arena entrance
→ Server validates access and party state
→ Readiness check
→ ArenaService reserves or selects encounter destination
→ Transfer payload contains only trusted identifiers
→ Destination server reloads authoritative player data
→ Encounter begins after all eligible players are ready
→ Completion is recorded server-side
→ Rewards are granted idempotently
→ Party returns to an appropriate world location
```

---

## 13. Recommended Project Structure

The exact toolchain may change, but the logical ownership should remain clear.

```text
bullet-hell/
├── README.md
├── default.project.json
├── aftman.toml
├── wally.toml
├── selene.toml
├── stylua.toml
├── docs/
│   ├── design/
│   ├── systems/
│   ├── content/
│   └── decisions/
├── tests/
├── src/
│   ├── ReplicatedFirst/
│   │   └── Loading.client.luau
│   ├── ReplicatedStorage/
│   │   ├── Shared/
│   │   │   ├── Config/
│   │   │   │   ├── Weapons/
│   │   │   │   ├── Mods/
│   │   │   │   ├── Skills/
│   │   │   │   ├── Enemies/
│   │   │   │   ├── Bosses/
│   │   │   │   ├── Zones/
│   │   │   │   ├── Quests/
│   │   │   │   └── Balance/
│   │   │   ├── Combat/
│   │   │   │   ├── DamageCalculator.luau
│   │   │   │   ├── StatCalculator.luau
│   │   │   │   ├── ProjectileMath.luau
│   │   │   │   ├── StatusEffects.luau
│   │   │   │   └── Tags.luau
│   │   │   ├── Network/
│   │   │   │   ├── Events.luau
│   │   │   │   ├── Schemas.luau
│   │   │   │   └── RateLimits.luau
│   │   │   ├── Types/
│   │   │   └── Utility/
│   │   ├── Assets/
│   │   └── Packages/
│   ├── ServerScriptService/
│   │   ├── ServerBootstrap.server.luau
│   │   └── Services/
│   │       ├── PlayerDataService.luau
│   │       ├── CombatService.luau
│   │       ├── WeaponService.luau
│   │       ├── ModService.luau
│   │       ├── SkillService.luau
│   │       ├── EnemyService.luau
│   │       ├── BossService.luau
│   │       ├── ArenaService.luau
│   │       ├── PvPService.luau
│   │       ├── ZoneService.luau
│   │       ├── LootService.luau
│   │       ├── RewardService.luau
│   │       ├── QuestService.luau
│   │       ├── WorldService.luau
│   │       ├── FactionService.luau
│   │       ├── BountyService.luau
│   │       ├── AntiAbuseService.luau
│   │       └── MatchmakingService.luau
│   ├── ServerStorage/
│   │   ├── Enemies/
│   │   ├── Bosses/
│   │   ├── Arenas/
│   │   └── ServerAssets/
│   ├── StarterPlayer/
│   │   └── StarterPlayerScripts/
│   │       ├── ClientBootstrap.client.luau
│   │       └── Controllers/
│   │           ├── InputController.luau
│   │           ├── CameraController.luau
│   │           ├── WeaponController.luau
│   │           ├── MovementController.luau
│   │           ├── EffectsController.luau
│   │           ├── AudioController.luau
│   │           ├── UIController.luau
│   │           ├── InteractionController.luau
│   │           └── ZoneController.luau
│   ├── StarterGui/
│   └── Workspace/
│       ├── World/
│       ├── ArenaEntrances/
│       ├── SpawnVolumes/
│       ├── ZoneVolumes/
│       └── Interactables/
└── tools/
```

### Architectural rules

- Configuration modules contain data, not mutable runtime state.
- Services communicate through defined methods and signals.
- Controllers never grant rewards or decide damage.
- Remote instances are declared centrally.
- Network payloads have schemas, limits, and validation.
- World objects use tags and attributes instead of hard-coded paths where practical.
- Content modules reference stable string IDs, not display names.
- Saved data includes a schema version and migrations.

### Workstream ownership

Implementation is intentionally divided into two independent workstreams. The **code workstream** owns Luau modules, runtime behavior, validation, schemas, automated tests, and code-managed configuration. The **Roblox Studio workstream** owns experience configuration, places, world construction, assets, authored Instances, tags, attributes, collision groups, spawn points, arena markers, and platform publishing.

Neither workstream should quietly create dependencies that are not listed in the integration contract below.

---

## Code Workstream (Your Team)

This track can be developed largely in source control and synchronized into Roblox Studio. It does not include building terrain, arranging the map, publishing the experience, or authoring final Roblox assets.

### C1. Repository and toolchain

- [ ] Initialize Git and write the project README.
- [ ] Create the source tree shown in this document.
- [ ] Configure Rojo mapping in `default.project.json`.
- [ ] Configure the chosen package manager and pin dependencies.
- [ ] Add formatting and static-analysis configuration.
- [ ] Add a command or script for building a `.rbxlx` or place artifact.
- [ ] Document local setup, sync, test, and build commands.
- [ ] Add continuous checks for formatting, linting, types, and tests.

**Deliverable:** A clean repository that can be synchronized into a blank Studio place without manual script copying.

### C2. Shared types, IDs, and registries

- [ ] Define stable ID conventions for weapons, mods, skills, enemies, bosses, zones, quests, items, and effects.
- [ ] Define strict Luau types for all major data structures.
- [ ] Create registries that reject duplicate IDs during startup.
- [ ] Add configuration validators with understandable error messages.
- [ ] Define standard tags and attributes expected from Studio-authored content.
- [ ] Export a human-readable content contract for the Studio workstream.

**Deliverable:** Invalid content fails during development startup instead of producing unexplained runtime behavior.

### C3. Bootstrap and lifecycle

- [ ] Implement deterministic service initialization order.
- [ ] Implement client controller initialization.
- [ ] Add startup failure reporting.
- [ ] Add cleanup utilities for player, character, arena, and encounter lifecycles.
- [ ] Prevent duplicate initialization during Studio testing.

**Deliverable:** Server services and client controllers start once, report failures clearly, and clean up connections reliably.

### C4. Networking layer

- [ ] Declare all remote events and functions centrally.
- [ ] Define payload schemas and maximum payload sizes.
- [ ] Add per-player, per-action rate limits.
- [ ] Reject unknown fields and invalid types.
- [ ] Add monotonically increasing sequence IDs for rapid combat actions.
- [ ] Add structured rejection reasons for debugging without exposing sensitive validation logic to clients.
- [ ] Instrument accepted, rejected, and rate-limited requests.

**Deliverable:** No gameplay system creates an unregistered or unvalidated remote ad hoc.

### C5. Character and movement interfaces

- [ ] Implement input-independent movement requests for sprint, crouch, dodge, and mantle.
- [ ] Implement server checks for cooldowns, stamina, distance, and legal state.
- [ ] Define interfaces for first-person viewmodels and character animation hooks.
- [ ] Handle respawn, death, seating, teleporting, and character replacement.
- [ ] Support keyboard/mouse, gamepad, and touch action bindings.

**Studio dependency:** Character rig choice, animation asset IDs, physical collision setup, and traversal markers.

### C6. Weapon foundation

- [ ] Implement weapon definitions and registry.
- [ ] Implement equip, unequip, fire, reload, and cancel states.
- [ ] Implement hitscan first, then reusable projectile support.
- [ ] Implement recoil, spread, falloff, critical regions, and ammunition.
- [ ] Implement server-authoritative firing validation.
- [ ] Implement client prediction and reconciliation for presentation.
- [ ] Provide interfaces for viewmodels, world models, sounds, muzzle attachments, and animations.
- [ ] Add automated tests for cadence, ammunition, reload interruption, and range.

**Studio dependency:** Weapon models, attachments, animations, audio, and viewmodel alignment.

### C7. Damage, health, and status effects

- [ ] Implement the typed `DamageContext` pipeline.
- [ ] Implement PvE and PvP damage profiles.
- [ ] Implement armor, shields, critical hits, stagger, and death.
- [ ] Implement timed status effects with stacking policies.
- [ ] Add recursion and trigger-depth limits.
- [ ] Add friendly-fire and immunity hooks.
- [ ] Emit consistent combat events for UI, audio, quests, and contribution tracking.

**Deliverable:** Every damage source uses one auditable path.

### C8. Mods and stat calculation

- [ ] Implement mod definitions, slots, tags, and compatibility checks.
- [ ] Implement the documented deterministic calculation order.
- [ ] Cache final builds and invalidate caches only when relevant state changes.
- [ ] Implement triggered mod effects through a controlled effect registry.
- [ ] Add hard caps and mode-specific coefficients.
- [ ] Produce a serializable build summary for UI and persistence.
- [ ] Add unit tests for conflicting, stacked, and off-slot modifiers.

**Deliverable:** Server and client produce identical display stats, while the server remains authoritative.

### C9. Skills and progression

- [ ] Implement skill definitions, prerequisites, unlocks, loadouts, and respec rules.
- [ ] Connect skill effects to the same trigger vocabulary used by mods.
- [ ] Implement weapon mastery and faction reputation interfaces.
- [ ] Separate permanent progression from temporary run state.
- [ ] Add server checks for every unlock and loadout mutation.

**Deliverable:** At least three gunsmithing skills produce visible, testable changes to weapon behavior.

### C10. Enemy and encounter runtime

- [ ] Implement enemy definitions and spawn requests.
- [ ] Implement reusable state-machine utilities.
- [ ] Implement targeting, threat, damage reception, and death.
- [ ] Implement encounter budgets and activation distance.
- [ ] Provide behavior hooks for authored spawn volumes and navigation regions.
- [ ] Support deterministic cleanup when players leave an encounter.

**Studio dependency:** Enemy rigs, animations, navigation-ready geometry, spawn volumes, cover markers, and encounter boundaries.

### C11. Boss and bullet-pattern runtime

- [ ] Implement boss state and phase machines.
- [ ] Implement modular attack definitions.
- [ ] Implement deterministic pattern seeds and timestamps.
- [ ] Implement server-side hit evaluation with simplified shapes.
- [ ] Implement client-side projectile visualization and pooling.
- [ ] Support arena marker lookups through tags and stable attributes.
- [ ] Implement wipe, reset, reconnect, victory, and cleanup behavior.
- [ ] Add a debug visualizer for hit volumes and arena markers.

**Studio dependency:** Boss rig, arena geometry, attack markers, VFX assets, sounds, animations, and safe spawn locations.

### C12. Zones and PvP rules

- [ ] Implement zone membership from tagged Studio volumes.
- [ ] Implement sanctuary, civilized, frontier, contested, and arena rule sets.
- [ ] Implement `PvPService:CanDamage()` as the single permission gate.
- [ ] Implement spawn and transition protection.
- [ ] Implement combat tagging and combat-logging rules.
- [ ] Implement repeat-victim reward suppression.
- [ ] Implement party, team, duel, and event eligibility hooks.
- [ ] Replicate the current zone and PvP state to the HUD.

**Studio dependency:** Correctly shaped and tagged zone volumes, barriers, spawn points, and visual boundary assets.

### C13. Arena and teleport flow

- [ ] Implement arena access requirements and party readiness.
- [ ] Implement reserved-server or destination-place integration.
- [ ] Validate transfer data as identifiers only; reload authoritative profiles at the destination.
- [ ] Implement retry-safe completion and reward transaction IDs.
- [ ] Implement disconnect, teleport failure, and return-to-world handling.
- [ ] Add local Studio fallbacks so encounters can be tested without published teleports.

**Studio dependency:** Published place IDs, arena entrances, destination spawn markers, and platform access configuration.

### C14. Inventory, loot, and economy

- [ ] Implement item instances and stackable resources.
- [ ] Implement server-owned pickup, grant, dismantle, crafting, and purchase operations.
- [ ] Implement personal or contribution-based loot ownership.
- [ ] Implement banked versus unbanked contested loot.
- [ ] Implement currency sources, sinks, caps, and audit events.
- [ ] Protect irreplaceable and paid items from loss rules.

**Deliverable:** Every item and currency mutation is authorized, attributable, and retry-safe.

### C15. Player data

- [ ] Implement versioned profiles and migrations.
- [ ] Implement session ownership or locking.
- [ ] Implement load failure handling that blocks unsafe mutations.
- [ ] Implement periodic and transition-triggered saves.
- [ ] Implement idempotent valuable transactions.
- [ ] Add development profiles that cannot contaminate production data.
- [ ] Test shutdown, disconnect, retry, and migration cases.

### C16. Quests, events, and rewards

- [ ] Implement typed quest objectives and server-side progression.
- [ ] Implement public-event state machines.
- [ ] Implement contribution scoring.
- [ ] Implement reward tables and deterministic entitlement checks.
- [ ] Add hooks for world markers, announcements, and authored event locations.

### C17. UI logic

- [ ] Implement HUD state stores and presenters.
- [ ] Implement inventory, loadout, modding, skill, party, map, death, and reward flows.
- [ ] Support input-focus changes across keyboard/mouse, gamepad, and touch.
- [ ] Show PvP state, at-risk loot, and safe-zone protection clearly.
- [ ] Expose accessibility settings for shake, flashes, colors, subtitles, and UI scale.
- [ ] Keep presentation separate from server mutations.

**Studio dependency:** Final interface art, fonts, icons, layout review, and device previews.

### C18. Security, telemetry, and tests

- [ ] Add exploit-oriented tests for every remote.
- [ ] Record impossible states without automatically punishing uncertain cases.
- [ ] Add performance counters for combat, AI, projectiles, memory, and bandwidth.
- [ ] Add unit tests for pure calculators and validators.
- [ ] Add integration tests for rewards, saves, zones, and arena state.
- [ ] Create multiplayer Studio test scripts and repeatable QA scenarios.

### Code workstream completion order

```text
C1–C3  Foundation
   ↓
C4     Networking
   ↓
C5–C7  Movement and base combat
   ↓
C8–C9  Builds and progression
   ↓
C10–C13 Enemies, bosses, PvP, arenas
   ↓
C14–C16 Persistence and game loops
   ↓
C17–C18 UI, hardening, telemetry, tests
```

---

## Roblox Studio Workstream (Other Team)

This track covers work that must be configured, authored, uploaded, placed, tagged, or verified through Roblox Studio and the Creator Dashboard. It should not contain hidden game rules in arbitrary workspace scripts.

### R1. Experience and place setup

- [ ] Create the Roblox experience under the correct owner or group.
- [ ] Establish development, staging, and production publishing rules.
- [ ] Create the main open-world place.
- [ ] Create a separate arena place if major arenas will use reserved servers.
- [ ] Record universe and place IDs in the shared environment/configuration document.
- [ ] Configure team creation and collaborator permissions.
- [ ] Configure supported devices, server capacity, avatar type, and character settings.
- [ ] Enable only the platform services the design requires.

**Handoff:** Experience owner, universe ID, place IDs, server capacity, avatar choice, and access permissions.

### R2. Place and world settings

- [ ] Configure `StreamingEnabled` and initial streaming settings.
- [ ] Set gravity, fallen-parts height, character jump/movement defaults, and workspace behavior.
- [ ] Configure lighting technology, atmosphere, time of day, and post-processing baseline.
- [ ] Define collision groups for players, enemies, projectiles, viewmodels, world props, and safe-zone barriers.
- [ ] Configure audio rolloff conventions and sound groups.
- [ ] Verify that world geometry uses appropriate collision fidelity.

**Handoff:** A written settings sheet containing every non-default place property relied upon by code or content.

### R3. Blockout and scale test

- [ ] Build a graybox hub, frontier, contested valley, and boss arena.
- [ ] Establish standard dimensions for doors, corridors, cover, stairs, jump gaps, and arena lanes.
- [ ] Test sight lines for rifles and close-range routes for shotguns.
- [ ] Validate spawn-to-objective travel times.
- [ ] Validate boss-pattern spacing at the intended player movement speed.
- [ ] Test with actual Roblox avatars and camera settings, not only free camera.

**Handoff:** Playable graybox place with no final-art requirement.

### R4. Required folders and authored Instances

Create and preserve these logical containers in the place:

```text
Workspace
├── World
├── ArenaEntrances
├── SpawnVolumes
├── ZoneVolumes
├── EncounterMarkers
├── NavigationMarkers
└── Interactables

ServerStorage
├── Enemies
├── Bosses
└── Arenas

ReplicatedStorage
└── Assets
    ├── Weapons
    ├── VFX
    ├── Audio
    └── UI
```

- [ ] Do not rename required containers without updating the shared contract.
- [ ] Use tags and attributes for authored content instead of embedding scripts in every model.
- [ ] Assign each authored gameplay object a stable `ContentId` attribute.
- [ ] Keep purely decorative objects outside gameplay marker containers.

### R5. Tags and attributes

The exact names must be agreed with the code team before mass-authoring content. Initial recommendations:

| Instance purpose | Tag | Required attributes |
|---|---|---|
| Zone volume | `GameZone` | `ZoneId` |
| Player spawn | `PlayerSpawn` | `SpawnId`, `SpawnType` |
| Enemy spawn volume | `EnemySpawnVolume` | `EncounterId`, `SpawnGroup` |
| Arena entrance | `ArenaEntrance` | `ArenaId` |
| Boss marker | `BossMarker` | `ArenaId`, `MarkerId` |
| Attack origin | `AttackOrigin` | `ArenaId`, `MarkerId` |
| Interactable | `Interactable` | `InteractionId`, `InteractionType` |
| Extraction point | `ExtractionPoint` | `ZoneId`, `ExtractionId` |
| Safe-zone barrier | `SafeZoneBarrier` | `ZoneId` |
| Navigation hint | `NavigationHint` | `HintType`, `GroupId` |

- [ ] Build a validation place or plugin workflow that reveals missing attributes.
- [ ] Never reuse a stable ID for different content.
- [ ] Keep display names independent from stable IDs.

### R6. Character rigs and animations

- [ ] Confirm R6 or R15 and keep it consistent across places.
- [ ] Create or acquire first-person arms/viewmodels.
- [ ] Author idle, equip, fire, reload, sprint, crouch, dodge, mantle, hit, downed, revive, and death animations.
- [ ] Publish animations under the correct experience owner.
- [ ] Record animation asset IDs in the asset manifest.
- [ ] Add named animation markers required by code, such as magazine removal, insertion, chambering, and fire events.
- [ ] Verify animation ownership in group-owned experiences.

### R7. Weapon assets

- [ ] Create rifle and shotgun world models.
- [ ] Create matching first-person viewmodels.
- [ ] Add agreed attachments such as `Muzzle`, `AimPoint`, `LeftHandGrip`, `Magazine`, and casing/effect origins.
- [ ] Set primary parts and pivots consistently.
- [ ] Remove unnecessary collision and mass from cosmetic parts.
- [ ] Create visual variants for the initial six mods where required.
- [ ] Publish and catalog fire, reload, dry-fire, equip, and impact sounds.

**Handoff:** Asset manifest mapping stable weapon/mod IDs to models, attachments, animations, sounds, icons, and ownership.

### R8. Enemy and boss assets

- [ ] Create rigs with consistent root parts, attachment conventions, and hit regions.
- [ ] Tag or name weak-point collision objects according to the contract.
- [ ] Author locomotion, attack, stagger, transition, defeat, and idle animations.
- [ ] Place sound and VFX attachment points.
- [ ] Configure collision groups and network ownership expectations.
- [ ] Test rigs on slopes, stairs, narrow passages, and arena edges.
- [ ] Provide simplified collision geometry where visual meshes are complex.

### R9. Arena authoring

- [ ] Build the Storm Engine arena to the approved gameplay dimensions.
- [ ] Place and identify player spawns, boss spawn, attack origins, phase markers, add spawns, safe return points, and boundary volumes.
- [ ] Ensure walls and cover block the attacks intended to respect line of sight.
- [ ] Prevent players from leaving, climbing outside, or becoming trapped during an encounter.
- [ ] Create readable floor materials for telegraphs.
- [ ] Create entrance, locked, active, completed, and reset presentation states.
- [ ] Test all marker IDs with the code validation tools.

### R10. Zone construction

- [ ] Create non-overlapping zone volumes for sanctuary, civilized, frontier, contested, and arena spaces.
- [ ] Add visual transitions before rule transitions.
- [ ] Create safe-zone barriers that cannot be exploited by shooting across the boundary.
- [ ] Place multiple protected respawn options.
- [ ] Create contested-zone extraction routes with more than one tactical approach.
- [ ] Verify that streaming does not unload critical zone boundaries near players.

### R11. Navigation and encounter placement

- [ ] Verify walkable navigation on all combat surfaces.
- [ ] Add authored hints for jump links, special traversal, cover, or restricted paths when required.
- [ ] Place enemy spawn volumes outside direct player view where appropriate.
- [ ] Provide enough space for enemy archetypes to perform their intended roles.
- [ ] Prevent enemies from spawning inside geometry or safe areas.
- [ ] Test encounter boundaries and cleanup distances.

### R12. VFX and audio language

- [ ] Define consistent colors and shapes for friendly, hostile, unblockable, environmental, and interactable effects.
- [ ] Produce scalable projectile, muzzle, impact, status, telegraph, extraction, and zone-boundary effects.
- [ ] Provide low-cost alternatives for intensive effects.
- [ ] Create distinct audio cues for boss attacks and PvP state changes.
- [ ] Configure sound groups for music, effects, dialogue, ambience, and UI.
- [ ] Verify essential cues remain understandable without music.

### R13. UI assets and Studio layout

- [ ] Create HUD ScreenGuis and reusable visual components if UI is authored in Studio.
- [ ] Provide icons for weapons, mods, skills, statuses, currencies, zones, and inputs.
- [ ] Define safe-area and scaling behavior for desktop, console, tablet, and phone.
- [ ] Test text size, controller focus, touch targets, and localization expansion.
- [ ] Ensure UI art does not conceal boss telegraphs.
- [ ] Preserve stable component names required by the UI code, or provide a generated binding manifest.

### R14. Platform configuration

- [ ] Configure badges and record their IDs.
- [ ] Configure passes or developer products only after monetization approval.
- [ ] Configure localization tables and supported languages.
- [ ] Configure private-server behavior if offered.
- [ ] Prepare icons, thumbnails, screenshots, title, description, and maturity questionnaire responses.
- [ ] Configure analytics events or platform dashboards required by production.
- [ ] Review Roblox policy and age-rating requirements before public release.

### R15. Publishing and device QA

- [ ] Publish development builds only to the intended place/environment.
- [ ] Test real server joins rather than relying solely on local play.
- [ ] Test party teleports and reserved-server arenas in published builds.
- [ ] Test keyboard/mouse, controller, phone, and tablet layouts.
- [ ] Test low graphics quality and constrained devices.
- [ ] Verify asset permissions after publishing under the final owner.
- [ ] Maintain a rollback copy or known-good published version.

### Roblox Studio workstream completion order

```text
R1–R2  Experience and settings
   ↓
R3–R5  Graybox, containers, tags, attributes
   ↓
R6–R8  Character, weapon, enemy, and boss assets
   ↓
R9–R11 Arena, zones, navigation, encounters
   ↓
R12–R13 Effects, audio, and UI presentation
   ↓
R14–R15 Platform configuration, publishing, device QA
```

---

## Integration Contract Between Teams

The project should maintain one version-controlled contract document or module containing the following information.

### Shared contract contents

- Stable content IDs
- CollectionService tag names
- Required Instance attributes and types
- Required folder/container names
- Model pivot and attachment conventions
- Animation marker names
- Collision-group names and intended interactions
- Zone IDs and rule sets
- Arena marker IDs
- Asset IDs and ownership
- Place IDs and environment mapping
- Remote payload schemas
- Performance budgets
- Minimum test scenarios

### Responsibility boundary

| Concern | Code workstream | Studio workstream |
|---|---|---|
| Weapon behavior | Implement and validate | Supply models, attachments, animations, audio |
| Boss logic | State machine, damage, timing | Rig, arena, markers, animations, VFX |
| Zone rules | Detect and enforce rules | Build, tag, and visually communicate volumes |
| PvP | Eligibility, damage, rewards | Boundaries, spawns, readable world cues |
| Projectiles | Simulate hits and render runtime effects | Supply meshes, textures, emitters, sounds |
| UI | State, input, behavior | Visual assets, layout approval, device review |
| Persistence | Implement and test | Configure/test published environment access |
| Teleports | Implement retries and payload validation | Create places, publish, provide IDs and permissions |
| Enemies | Runtime AI and combat | Rigs, animations, navigation-ready spaces |
| Performance | Measure runtime and enforce budgets | Optimize geometry, textures, effects, and streaming layout |

### Integration milestones

#### I1. Empty-place handshake

- Code synchronizes successfully into the Studio place.
- Required folders are present.
- A shared validation command reports no missing foundation settings.
- One server and two clients can start without errors.

#### I2. Weapon handshake

- The Studio team supplies one rifle model and required attachments.
- The code team binds it through the asset manifest.
- Equip, fire, reload, replication, and damage work in a published multiplayer test.

#### I3. Zone handshake

- The Studio team supplies one sanctuary and one contested volume.
- The code team detects transitions and enforces damage rules.
- Both teams verify safe-zone edge cases together.

#### I4. Enemy handshake

- The Studio team supplies one enemy rig, spawn volume, and navigation-ready room.
- The code team spawns, controls, damages, and cleans up the enemy.
- Animations, weak points, sounds, and rewards work end to end.

#### I5. Boss handshake

- The Studio team supplies the arena, boss rig, markers, and required assets.
- The code team runs two phases, defeat, wipe, reset, and rewards.
- Both teams profile the maximum projectile pattern together.

#### I6. World-loop handshake

- A player leaves the hub, enters the frontier, crosses into contested territory, completes or escapes an objective, enters the arena, receives a reward, and returns safely.
- The saved profile survives disconnect and rejoin.
- Device and multiplayer checks pass in a published build.

### Change-control rule

Any change to a shared name, tag, attribute, attachment, animation marker, place ID, or collision group requires:

1. Updating the shared contract.
2. Updating validation where possible.
3. Notifying the other workstream.
4. Testing the affected integration milestone again.

This prevents invisible Studio changes from breaking code and prevents code changes from invalidating authored world content.

---

## 14. Core Data Models

These examples communicate shape and ownership; field names can evolve during implementation.

### 14.1 Weapon definition

```lua
return {
    Id = "frontier_rifle",
    DisplayName = "Frontier Rifle",
    Family = "AssaultRifle",
    Tags = { "Ballistic", "Automatic" },

    BaseStats = {
        Damage = 24,
        FireRate = 8,
        MagazineSize = 30,
        ReloadTime = 2.1,
        SpreadDegrees = 1.2,
        Range = 500,
        ProjectileSpeed = 900,
        CriticalMultiplier = 1.5,
    },

    Slots = {
        Barrel = 1,
        Magazine = 1,
        Optic = 1,
        Core = 1,
    },

    DamageType = "Kinetic",
}
```

### 14.2 Mod definition

```lua
return {
    Id = "explosive_core",
    DisplayName = "Explosive Core",
    Slot = "Core",
    Rarity = "Prototype",

    RequiredWeaponTags = { "Ballistic" },
    IncompatibleTags = { "Beam", "ExplosiveCore" },
    GrantedTags = { "ExplosiveCore" },

    StatModifiers = {
        DamageMultiplier = 0.85,
    },

    Effects = {
        {
            Trigger = "OnHit",
            Effect = "Explosion",
            Radius = 7,
            PvEDamageMultiplier = 0.40,
            PvPDamageMultiplier = 0.22,
        },
    },
}
```

### 14.3 Damage context

```lua
type DamageContext = {
    attackerUserId: number?,
    sourceId: string,
    weaponId: string?,
    damageType: string,
    baseDamage: number,
    hitPosition: Vector3,
    hitRegion: string?,
    isCritical: boolean,
    isPvP: boolean,
    sequenceId: number,
}
```

### 14.4 Player profile

```lua
return {
    SchemaVersion = 1,

    Progression = {
        Level = 1,
        Experience = 0,
        UnlockedRegions = { "starting_frontier" },
        Reputation = {},
    },

    Inventory = {
        Weapons = {},
        Mods = {},
        Materials = {},
        Cosmetics = {},
    },

    Loadouts = {},
    Skills = {
        Unlocked = {},
        Equipped = {},
    },

    Currencies = {
        Credits = 0,
        Components = 0,
        BossTokens = {},
        FactionMarks = {},
    },

    Statistics = {},
    Settings = {},
}
```

### 14.5 Zone definition

```lua
return {
    Id = "rust_valley_contested",
    DisplayName = "Rust Valley",
    RuleSet = "Contested",
    PvPEnabled = true,
    ExtractionRequired = true,
    RewardMultiplier = 1.5,
    MinimumLevel = 10,
    SpawnProtectionSeconds = 8,
}
```

---

## 15. Networking and Security

### 15.1 Never trust client claims

The server must independently validate:

- Shot cadence
- Ammunition
- Reload timing
- Equipped weapon and mods
- Shot origin near the player's legal firing position
- Aim direction within plausible limits
- Range and line of sight
- Movement speed and teleport distance
- Ability cooldowns and resource costs
- PvP eligibility
- Inventory transactions
- Quest and reward completion

### 15.2 Remote design

Use narrow remotes with explicit payloads. Avoid a generic remote that accepts arbitrary action names and tables.

Recommended categories:

- Weapon action requests
- Movement ability requests
- Interaction requests
- Inventory/loadout requests
- Arena and party requests
- Server-to-client combat confirmations
- Server-to-client world state

### 15.3 Rate limiting

Apply per-player and per-action limits. Exceeding a limit should usually discard the request, record a signal, and only escalate after repeated impossible behavior.

### 15.4 Lag compensation

For hitscan PvP:

- Store a brief server-side position history.
- Rewind targets to an interpolated historical pose within a strict maximum window.
- Validate the shooter position and world obstruction at the shot time.
- Never accept a client-provided hit result as authoritative.
- Monitor whether high latency creates a measurable advantage.

### 15.5 Persistence safety

- Use session ownership or locking.
- Save periodically and on meaningful transitions.
- Make reward grants idempotent with unique transaction IDs.
- Version the schema and test migrations.
- Keep an audit trail for valuable grants and trades.
- Do not save on every shot, kill, or minor inventory mutation.

---

## 16. Performance Strategy

### 16.1 Bullet-hell projectiles

Do not represent every projectile as a fully replicated physical Part.

Recommended model:

- Server owns deterministic attack definitions and start timestamps.
- Clients render most projectile visuals locally.
- Server evaluates simplified projectile paths, hit volumes, or sampled positions.
- Important projectiles replicate compact state, not per-frame transforms.
- Visual objects use pooling rather than repeated creation and destruction.

### 16.2 AI

- Update distant enemies less frequently.
- Disable or simplify AI outside active player areas.
- Separate decision frequency from movement/render frequency.
- Use encounter budgets per region.
- Avoid pathfinding requests every frame.
- Prefer authored combat spaces with reliable navigation.

### 16.3 Effects

- Pool tracers, decals, projectiles, sounds, and damage indicators.
- Cap simultaneous cosmetic effects.
- Provide low, medium, and high effect presets.
- Preserve telegraphs at every graphics setting.
- Avoid large transparent layers covering the screen.

### 16.4 Performance budgets

Define budgets during the vertical slice for:

- Active enemies per player
- Active visual projectiles
- Server combat update time
- Client frame time
- Network traffic per player
- Memory on lower-end mobile devices
- Maximum simultaneous audio sources

Record actual measurements before expanding encounter scale.

---

## 17. UI and Player Feedback

### 17.1 Combat HUD

- Crosshair showing spread and state
- Ammo and reload/heat state
- Health, shields, and status effects
- Dodge or stamina availability
- Tactical ability and ultimate cooldowns
- Directional damage feedback
- Boss health and phase information
- Party health and downed state
- PvP state and current zone rule

### 17.2 Build UI

The modification screen should show:

- Base and final weapon stats
- Difference caused by the selected mod
- Tradeoffs, incompatible tags, and limits
- PvE and PvP differences
- Active trigger effects
- Saved loadouts
- A test-range shortcut where possible

### 17.3 World communication

- Use landmarks before map icons.
- Clearly mark safe, frontier, and contested borders.
- Give a confirmation before entering forced PvP.
- Display what loot is currently at risk.
- Use pings for enemies, locations, loot, and retreat.
- Avoid covering boss telegraphs with quest or reward popups.

### 17.4 Accessibility

- Remappable controls where supported
- Hold/toggle options for aiming and sprinting
- Adjustable camera shake and flashes
- Colorblind-safe threat communication
- Subtitle and sound-cue alternatives
- Scalable UI and readable mobile layouts
- Separate music, effects, dialogue, and interface volume

---

## 18. Development Roadmap

### Phase 0: Preproduction

Deliverables:

- One-page vision and pillars
- Combat reference targets
- PvP zone and loss rules
- Technical architecture decision record
- Graybox region plan
- Weapon/mod spreadsheet or configuration schema
- Boss mechanic storyboard

Exit condition: the team agrees on what the vertical slice proves and what it intentionally excludes.

### Phase 1: Combat prototype

Build:

- First-person controller
- One rifle
- Server-validated hitscan firing
- Damage and health
- One target dummy
- Basic recoil, hit feedback, and reload
- Keyboard/mouse plus one secondary input scheme

Exit condition: firing feels responsive while the server remains authoritative.

### Phase 2: Combat sandbox

Build:

- Rifle and shotgun
- Three enemy archetypes
- Dodge and one tactical ability
- Damage types and status effects
- PvE/PvP damage profiles
- Small deathmatch test area
- Basic telemetry

Exit condition: PvE and PvP are both playable without duplicating the combat system.

### Phase 3: Build system

Build:

- Weapon definitions
- Four mod slots
- Six initial mods
- Final stat calculator
- Compatibility rules
- Three gunsmithing skills
- Inventory and loadout UI
- Test range

Exit condition: multiple viable builds feel mechanically different and reproduce deterministically on server and client.

### Phase 4: Boss slice

Build:

- One arena
- One boss with two phases
- Three core attacks plus one transition
- Local projectile rendering
- Party revive flow
- Contribution and rewards
- Failure and reset states

Exit condition: 1–4 players can complete, fail, retry, and receive rewards without manual intervention.

### Phase 5: World slice

Build:

- Hub
- One frontier region
- One contested subzone
- Arena entrance landmark
- Streaming and encounter spawning
- One quest chain
- Two public events
- Extraction objective

Exit condition: the complete prepare-explore-fight-extract-upgrade loop functions in one region.

### Phase 6: Persistence and hardening

Build:

- Versioned player profiles
- Save/load recovery
- Reward idempotency
- Remote rate limits
- Basic anti-abuse signals
- Disconnect and rejoin handling
- Mobile and low-end performance passes

Exit condition: repeated tests do not duplicate or lose progression, and common exploit attempts fail safely.

### Phase 7: Alpha content

Add:

- More weapon families
- Second region
- Second and third bosses
- Factions and reputation
- Expanded quests
- Economy tuning
- Onboarding and accessibility

Do not enter this phase until the vertical slice meets its acceptance criteria.

---

## 19. Vertical Slice Specification

### 19.1 Included content

- One safe hub
- One compact frontier region
- One clearly marked contested valley
- One instanced boss arena located within the world
- Two weapon families: assault rifle and shotgun
- Six gun mods
- Three gunsmithing skills
- Three standard enemy archetypes
- One elite enemy
- One two-phase boss
- One public event
- One extraction objective
- Four-player parties
- Basic inventory, loadouts, rewards, and saving

### 19.2 Suggested six mods

1. Heavy Barrel
2. High-Caliber Magazine
3. Explosive Core
4. Tracking Rounds
5. Suppressor
6. Ricochet Core

### 19.3 Suggested boss

**The Storm Engine**

- Phase one teaches radial waves and rotating gaps.
- Players destroy exposed conductors to create damage windows.
- The transition forces traversal through a moving projectile pattern.
- Phase two combines targeted lines, orbiting projectiles, and summoned repair drones.
- A clear enrage timer increases pattern speed, not merely boss damage.
- Its signature reward is an Arc or projectile-routing mod.

### 19.4 Explicitly excluded from the first slice

- Trading
- Clans or guild wars
- Player-built bases
- Large raids
- Invasion PvP
- Extensive procedural generation
- More than one full region
- Large numbers of weapon families
- Permanent full-loot loss
- Competitive ranked seasons

---

## 20. Testing and Acceptance Criteria

### 20.1 Combat

- [ ] Firing responds immediately under normal latency.
- [ ] The server rejects impossible fire rates and ammunition states.
- [ ] Damage results match the equipped build.
- [ ] Recoil, spread, and range are understandable to players.
- [ ] Death and respawn complete without leaving invalid combat state.

### 20.2 Mods and skills

- [ ] Installing and removing a mod updates the correct stats.
- [ ] Invalid slot and tag combinations are rejected by the server.
- [ ] Triggered effects cannot recursively activate without a defined limit.
- [ ] PvE and PvP values display accurately.
- [ ] Saved loadouts restore the same calculated build.

### 20.3 Boss

- [ ] Every damaging attack has a readable warning.
- [ ] The boss resets correctly after a party wipe or abandonment.
- [ ] One to four players can complete the encounter through scaling or mechanics.
- [ ] Projectiles remain readable on low graphics settings.
- [ ] Rewards cannot be claimed twice from one completion.

### 20.4 PvP

- [ ] Damage cannot cross a safe-zone boundary in either direction.
- [ ] Party and team rules are enforced server-side.
- [ ] Spawn protection works and ends when the player attacks.
- [ ] Repeated victim farming stops producing rewards.
- [ ] Death clearly reports the major cause.
- [ ] PvP remains playable at expected latency ranges.

### 20.5 Persistence

- [ ] Disconnecting during a save does not corrupt the profile.
- [ ] Rejoining does not duplicate rewards.
- [ ] Old schema versions migrate through automated tests.
- [ ] Valuable transactions have stable unique IDs.
- [ ] A failed data load prevents unsafe inventory mutation.

### 20.6 Performance

- [ ] Target devices maintain the chosen frame-rate goal in normal encounters.
- [ ] Maximum intended projectile patterns stay within client budgets.
- [ ] Full parties do not exceed server or network budgets.
- [ ] Entering a new streamed region does not break collision or objectives.
- [ ] Effects degrade gracefully while essential telegraphs remain visible.

---

## 21. Team Roles and Workflow

Small teams may combine roles, but ownership should remain explicit.

| Role | Primary ownership |
|---|---|
| Creative/game director | Vision, pillars, scope, final design calls |
| Gameplay engineer | Weapons, movement, abilities, combat |
| Network/server engineer | Authority, persistence, services, security |
| Encounter designer | Enemies, bosses, arenas, balance |
| World designer | Regions, traversal, landmarks, event spaces |
| UI/UX designer | HUD, inventory, build interface, accessibility |
| 3D/VFX/audio artists | Assets, effects, readability, identity |
| QA/data analyst | Test plans, telemetry, exploit cases, balance evidence |

### Recommended workflow

- Keep source-controlled code and configuration outside binary place files where possible.
- Review changes through small, focused branches.
- Require test steps for combat, economy, and save-data changes.
- Keep balancing values in configuration modules.
- Record architectural decisions under `docs/decisions`.
- Maintain a playable development build throughout production.
- Run multiplayer tests early; solo Studio testing is insufficient for this project.

---

## 22. Major Risks and Guardrails

### Scope expansion

**Risk:** Open world, PvP, RPG progression, FPS networking, modular weapons, and bullet hell each become separate projects.  
**Guardrail:** Do not add a second region until the vertical slice is fun and stable.

### Combat latency

**Risk:** Server authority feels slow, or generous client trust enables cheating.  
**Guardrail:** Predict presentation locally while validating outcomes on the server.

### Projectile performance

**Risk:** Replicated Parts and per-frame remote traffic overwhelm clients and servers.  
**Guardrail:** Use deterministic patterns, client rendering, compact replication, and object pools.

### PvP griefing

**Risk:** New players are repeatedly killed or blocked from progression.  
**Guardrail:** Protected progression routes, safe zones, spawn rules, and objective-driven rewards.

### Build imbalance

**Risk:** Mod combinations create one dominant build or an infinite trigger loop.  
**Guardrail:** Compatibility tags, effect budgets, trigger-depth limits, hard caps, and PvP coefficients.

### Data loss or duplication

**Risk:** Disconnects, retries, or teleports duplicate boss rewards or erase inventory.  
**Guardrail:** Versioned schemas, session ownership, idempotent reward transactions, and failure-safe loading.

### Visual overload

**Risk:** Players cannot distinguish danger from decoration.  
**Guardrail:** Establish a strict visual language and preserve gameplay cues at every effects setting.

### Stat inflation

**Risk:** Earlier content and lower-level players become irrelevant.  
**Guardrail:** Favor sidegrades, mechanics, and build diversity over exponential power growth.

---

## 23. Launch and Post-Launch Direction

### Minimum launch foundation

- Stable first-person combat
- Multiple viable weapon builds
- Protected PvE progression
- Clearly identified PvP spaces
- At least two complete regions
- Several replayable bosses
- Reliable profiles and rewards
- Mobile, gamepad, and keyboard/mouse support appropriate to the target audience
- Reporting, moderation, telemetry, and recovery procedures

### Sustainable content additions

The architecture should allow updates to add:

- A region package
- A weapon family
- A set of mods
- A skill branch
- A boss and arena
- A faction event
- A limited-time rule modifier

Prefer recombining existing systems in new ways over adding a new foundational system every update.

### Useful telemetry

Track aggregated, privacy-conscious gameplay measures such as:

- Weapon and mod pick rates
- Build win rates by PvP context
- Boss phase failure points
- Damage sources and time-to-defeat
- Zone population and abandonment
- Extraction success rates
- Economy sources and sinks
- Match latency and rejected-action rates
- New-player tutorial completion

Balance using both data and observed player experience. Popular does not always mean overpowered, and low usage may signal poor communication rather than weak mechanics.

---

## 24. Production Checklists

### Before implementation

- [ ] Confirm the player fantasy and design pillars.
- [ ] Choose the initial target devices and control schemes.
- [ ] Define safe, optional-PvP, and forced-PvP rules.
- [ ] Define exactly what can be lost on death.
- [ ] Approve the vertical-slice exclusions.
- [ ] Set frame, network, enemy, and projectile budgets.
- [ ] Decide which encounters use the open world versus isolated servers.

### Before adding content

- [ ] One rifle feels good.
- [ ] Server validation survives basic exploit attempts.
- [ ] PvE and PvP damage profiles are separate.
- [ ] Mod calculation is deterministic.
- [ ] One boss can reset and reward reliably.
- [ ] Save migrations and idempotent rewards are tested.
- [ ] Streaming works across the graybox region.

### Before public testing

- [ ] New-player onboarding is complete.
- [ ] Safe-zone boundaries are visually obvious.
- [ ] PvP entry and loss warnings are explicit.
- [ ] Reporting and blocking flows are available.
- [ ] Low-end client tests pass.
- [ ] Disconnect, teleport failure, and rejoin flows pass.
- [ ] Economy exploits and reward duplication have been tested.
- [ ] Analytics can identify the major funnel and combat failures.

### First playable milestone

The first meaningful milestone is complete when a group can:

1. Spawn in the hub.
2. Equip and modify a rifle or shotgun.
3. Enter the frontier.
4. Fight three enemy types.
5. Choose whether to enter a contested objective.
6. Discover and enter the Storm Engine arena.
7. Defeat or fail the boss cleanly.
8. Receive and save a build-changing reward.
9. Return to the hub and improve a loadout.
10. Repeat the loop without developer intervention.

---

## Closing Direction

The project should be developed from the inside out:

```text
Excellent shooting
→ trustworthy multiplayer combat
→ expressive weapon builds
→ one memorable boss
→ one complete region
→ durable progression
→ broader world and content
```

The world is the container, but combat and builds are the product. A compact region containing one excellent weapon sandbox, one fair PvP objective, and one unforgettable boss will prove the concept more effectively than a huge unfinished map.
