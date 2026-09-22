# Bullet Hell

An open-world Roblox FPS RPG with bullet-hell boss encounters, modular weapon
builds, and structured PvPvE. The full design document lives at
[`docs/design/ROBLOX_RPG_PROJECT_SCAFFOLD.md`](docs/design/ROBLOX_RPG_PROJECT_SCAFFOLD.md).

**Current state: Milestone 1 — the Arena Slice.** Playable, code-only, no
authored art required. See [`docs/MILESTONE_1.md`](docs/MILESTONE_1.md).

---

## Quick start

```bash
./scripts/setup.sh   # downloads the pinned rojo, stylua, selene into tools/bin
make build           # writes build/BulletHell.rbxlx
```

Open `build/BulletHell.rbxlx` in Roblox Studio and press **Play**. There is
nothing else to configure — the world builds itself at runtime.

To iterate without rebuilding, run `make serve` and connect the
[Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004/Rojo)
to `localhost:34872`.

> Roblox Studio only runs on Windows and macOS. On Linux, build the place here
> and open it on a machine that has Studio, or run `make serve` here and point
> Studio at this machine.

## Commands

| Command | What it does |
|---|---|
| `make build` | Build `build/BulletHell.rbxlx` |
| `make serve` | Live-sync into an open Studio session |
| `make check` | Format check + static analysis + clean build (the CI gate) |
| `make format` | Apply StyLua formatting |
| `make notify` | Post the current build to Discord (needs `DISCORD_WEBHOOK_URL`) |
| `make clean` | Remove build artifacts |

Unit specs live in [`tests/`](tests) and run **in-engine** on every Studio
play-test — watch the Output window for `[Tests] N passed`. They run in Roblox
rather than headlessly because the modules under test use `Vector3`, `CFrame`
and `Random`, and a shim of those types would drift from the real engine.

## Controls

| Input | Action |
|---|---|
| `W A S D` | Move |
| `Mouse` | Look |
| `LMB` | Fire |
| `RMB` | Aim down sights |
| `R` | Reload |
| `1`–`5` / scroll | Switch weapon |
| `Shift` | Sprint |
| `C` / `Ctrl` | Crouch — **while sprinting, this slides** |
| `Space` (in air) | Double jump |
| `Q` | Dash — grants brief invulnerability |

Walk onto the purple pad north of spawn to enter the Storm Engine arena.

## What is in Milestone 1

- Five weapons — rifle, shotgun, pistol, SMG, marksman rifle — on one
  server-validated firing pipeline
- Slide, double jump, and dash, predicted locally and validated server-side
- Floating damage numbers that merge rapid hits and distinguish crits and
  weak points
- The Storm Engine: a two-phase bullet-hell boss with conductors, four
  pattern types, enrage, wipe, and reset
- A code-generated graybox hub, firing range, and arena, tagged to the
  integration contract so authored geometry is a drop-in replacement
- A combat HUD: spread-tracking crosshair, ammo, health, ability cooldowns,
  boss phase bar, and directional damage indicators

## Repository layout

```
src/ReplicatedStorage/Shared/   Config, types, pure combat math, network contracts
src/ServerScriptService/        Bootstrap + services (the authority)
src/StarterPlayer/.../Controllers/  Input, camera, weapon, movement, HUD, effects
tests/                          Unit specs, mounted at ServerScriptService.Tests
docs/                           Design doc, milestone plan, team contract
scripts/                        Toolchain setup, Discord build handoff
```

Three rules hold the architecture together:

1. **The server decides, the client presents.** No controller grants damage,
   ammo, or rewards.
2. **Shared math is shared, not duplicated.** Client prediction and server
   validation call the same functions, so they cannot disagree.
3. **Nothing hard-codes a name from the Studio contract.** Tags, attributes,
   containers, and collision groups all come from
   `src/ReplicatedStorage/Shared/Contract.luau`.

## Working with the Studio team

`docs/INTEGRATION_CONTRACT.md` is the handoff document: every tag, attribute,
container, collision group, and attachment name the code expects. It is
generated from the same module the code reads, so it cannot go stale silently.
