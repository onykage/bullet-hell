# ADR 0001 — Bullet patterns replicate as seeds, not projectiles

**Status:** Accepted, Milestone 1
**Context:** §16.1 of the design document, "Bullet-hell projectiles"

## Decision

A boss bullet pattern is replicated once, as a record of roughly 80 bytes:

```
{ patternId, instanceId, seed, startTime, origin, targetPosition, damage }
```

Server and client both expand that record through the same pure module,
`Shared/Combat/ProjectilePattern.luau`, which is a function of its arguments
alone — no workspace reads, no `os.clock`, no `math.random`.

- The **server** builds the shot list once and evaluates positions at a fixed
  20 Hz to decide who was hit.
- The **client** builds the identical shot list and evaluates positions every
  frame to draw pooled visuals.

## Alternatives rejected

**Replicated physical Parts.** The obvious approach and the one the design
document explicitly warns against. A single `radial_wave` is 144 projectiles;
four of them overlapping is ~600 replicated Parts with physics state, for one
boss, before any other player's tracers. It does not survive contact with a
mobile client.

**Server streams positions each frame.** Correct but expensive: per-frame
remote traffic scaling with projectile count times player count, and it makes
pattern density a bandwidth decision rather than a design one.

## Consequences

Good:
- Pattern density becomes nearly free on the network. Adding projectiles to a
  pattern costs client draw calls and server hit-test time, nothing else.
- Server and client cannot disagree about where a bullet is, because neither
  one is told — both compute it.
- Patterns are trivially unit-testable, and they are: see
  `tests/ProjectilePattern.spec.luau`.

Costs:
- `ProjectilePattern` must stay pure. Any impurity — reading a part's position,
  calling `math.random` — silently desyncs the two sides, and the symptom is
  players taking damage from bullets that were never on their screen. The test
  suite asserts determinism for every declared pattern to catch this.
- Patterns cannot react to the world mid-flight. Homing, bouncing, and
  collision-aware projectiles need a different mechanism. That is an accepted
  limit for this class of attack; per-projectile behaviour belongs to weapon
  mods, which are server-simulated and far fewer in number.
- Clients joining mid-pattern see it from the start of its remaining life
  rather than its true age. Acceptable: patterns are short, and the telegraph
  is what carries the fairness guarantee.
