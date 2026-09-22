# ADR 0003 — Wall running is the sanctioned form of Roblox's wallhop glitch

**Status:** Accepted, Milestone 1
**Context:** Requested directly — "research wall run glitch and see if we can
purposely include it."

## The glitch

Roblox has a movement exploit known as the **wallhop** (also "wall climbing"),
[discovered 6 August 2013 and considered unpatchable](https://roblox.fandom.com/wiki/Wallhop).

The mechanism is a collision-detection quirk. Where two parts meet with no gap,
a player whose leg touches the seam and who turns roughly 45° sideways briefly
clips that leg *inside* the wall. The engine reads the clip as ground contact,
emits `HumanoidStateType.Landed`, and refunds the jump. Repeat at the next seam
and you climb any stacked-part wall in the game, indefinitely.

Players already know this technique, and any arena built from stacked parts —
ours included — is climbable with it.

## Decision

Build wall running as a first-class mechanic that **grants the same benefit the
glitch grants**, on terms we control, and bound the part that would break the
game.

The glitch's appeal is real and worth keeping: walls should give you back your
air options. What makes it destructive is that the refund is *per seam*, so the
climb is unbounded — and an unbounded vertical climb means players simply leave
the boss arena from above.

So the sanctioned version keeps the refund and bounds the climb:

| Glitch | Our mechanic |
|---|---|
| Jump refunded per seam | Air jump refunded per **wall jump**, granted by the server |
| Works on any stacked-part seam | Requires a near-vertical surface within reach, re-confirmed every frame |
| Unbounded climb | `MaxWallChain` attaches before touching ground; the same wall cannot be re-attached consecutively |
| Holds height indefinitely | Runs descend at `GravityScale` of normal gravity |
| Invisible to other players | Camera roll, attach boost, and shake make it legible |
| Rewards fighting the camera at 45° | Rewards momentum: requires speed and alignment along the wall |

Escape height is bounded by construction and asserted in
`tests/Movement.spec.luau`: a ground jump plus every allowed wall attach and
wall jump, all converting perfectly to height, reaches ~46 studs against a
64-stud arena ceiling.

## Alternatives rejected

**Detect and punish the glitch.** Unpatchable means unpatchable — the seam clip
happens in the physics engine, below anything a game script observes. Attempts
would produce false positives against players on bad connections, which the
design document explicitly warns against (§C18: do not automatically punish
uncertain cases).

**Build arenas with no seams.** Would mean no stacked geometry anywhere, which
is not a constraint the Studio workstream can reasonably work under.

**Ignore it.** Players who know the technique leave the arena; players who do
not are at a disadvantage they cannot see. Both are worse than teaching it.

## Consequences

Good:
- The arena ceiling and the chain limit are now *stated* invariants with a test
  behind them, rather than an assumption nobody checked.
- Movement gains real expression: cover pillars in the Storm Engine arena are
  tall and wide enough to run along, so the movement kit has a use during the
  fight rather than only between fights.
- The hub contains a practice pair of walls, so players meet the mechanic
  somewhere safe.

Costs:
- The seam glitch still exists. A determined player can still wallhop a stacked
  wall; we have not removed that, only made the legitimate route better and
  capped the arena so the glitch gains nothing worth having. The ceiling is the
  real guarantee, not the chain limit.
- Wall detection is two raycasts per frame per player. Cheap, but it is on the
  client's Heartbeat and scales with party size on the server's validation path.
- Roblox's constraint system is genuinely awkward here; the devforum is full of
  wall-run implementations that fling players or rotate them into the wall over
  time. Ours avoids `AlignOrientation` entirely and uses a velocity constraint
  with a light adhesion term, which is why the character does not re-orient.

## Sources

- [Wallhop — Roblox Wiki](https://roblox.fandom.com/wiki/Wallhop)
- [Help with Wall Running Script Raycasting — devforum](https://devforum.roblox.com/t/help-with-wall-running-script-raycasting/1762445)
- [Need ideas on wallrun alignment — devforum](https://devforum.roblox.com/t/need-ideas-on-wallrun-alignment/3098727)
- [AlignOrientation adding random linear velocity — devforum](https://devforum.roblox.com/t/alignorientation-adding-random-linear-velocity/3318383)
- [LinearVelocity sticking to walls / laggy collisions — devforum](https://devforum.roblox.com/t/linearvelocity-sticking-to-wallslaggy-collisions/3837351)
