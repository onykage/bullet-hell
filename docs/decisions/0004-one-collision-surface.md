# ADR 0004 — The world has exactly one walkable surface

**Status:** Accepted, Milestone 1
**Context:** Players were falling out of the world.

## The problem

The first graybox built each area as its own collidable slab: a 220×220 hub
floor, a 90×280 range floor, a 171×171 arena floor, with nothing between them
and nothing beyond them. Three separate bugs followed from that one decision:

1. **Void between areas.** The hub ended at z=110 and the arena began at z=615.
   Anything that put a player in between — a failed teleport, a dash off the
   edge, a wall jump — dropped them into nothing.
2. **An unsealed hub.** The hub wall was four 170-stud slabs on a ring of
   radius 112, whose circumference is 703 studs. 4 × 170 = 680. The missing
   23 studs were four open corners, and nobody recomputed the segment width
   after the radius was chosen.
3. **Lips and seams.** Adjacent slabs of different sizes meet at edges the
   character controller can catch on.

## Decision

One `Bedrock` part is the only collidable, raycastable ground in the world. Its
top face is exactly `y = 0`. Every visible floor — hub, range, arena, distance
stripes — is a decorative skin laid flush on top with `CanCollide = false` and
`CanQuery = false`.

Consequences of that single rule:

- There is no seam between floors, because there is only one floor.
- Ground raycasts (slide slope detection, grounding, wall-run height) all hit
  the same surface, so they cannot disagree with what the player is standing on.
- An invisible perimeter barrier rings the bedrock, so its edge is not itself a
  cliff.
- Wall rings are built by `Graybox.sealedRing`, which **derives** segment width
  from `2r·sin(π/n)` plus an overlap factor. A ring built this way cannot have a
  gap, whatever the radius is later changed to.
- The arena has an invisible ceiling, because wall jumping adds real height.

## Also: falling is recovered, not punished

`WorldBuilderService` watches for players below `y = -90` and returns them to a
spawn — an arena spawn if they fell inside the arena footprint, the hub
otherwise. `FallenPartsDestroyHeight` is pushed to -500 so recovery always wins
the race.

Death-on-fall punishes the player for a level-geometry bug, which is the wrong
party. It also hides the bug: a player who dies assumes they made a mistake,
while a player who is visibly rescued reports it. The recovery logs a warning
with the position they fell from, so the void that caught them is findable.

## Consequences

Good: no gaps are reachable by construction, and the ones that would be are
caught and reported rather than silently killing players.

Costs: the decorative surfaces cost draw calls for no collision benefit, and a
future authored world must either adopt the same convention or supply its own
sealed collision — the recovery watcher runs either way, but it is a safety
net, not a floor.
