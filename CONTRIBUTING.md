# Contributing

## Before you push

```bash
make check
```

That runs the same three gates CI does: StyLua formatting, Selene static
analysis, and a clean Rojo build. `make format` applies formatting.

If you touched `src/ReplicatedStorage/Shared/Contract.luau`, also run
`make contract` — CI fails if the generated handoff document is stale.

## The rules that matter

These are not style preferences. Each one exists because breaking it produces a
specific class of bug.

**1. The server decides; the client presents.**
No controller may grant damage, ammunition, currency, or progression. If a
client-side file needs to change a number that matters, it is asking the wrong
question — send a request and let a service validate it.

**2. Prediction and validation share their math.**
If the client computes something the server re-checks — spread, falloff,
cadence, ability cooldowns — both must call the same function in
`Shared/Combat` or `Shared/Config`. Two implementations of one rule will
diverge, and the symptom is honest players being rejected.

**3. All health changes go through `CombatService:ApplyDamage`.**
Nothing else writes to an entity's health. This is what makes damage auditable,
makes floating numbers correct by construction, and keeps the PvE/PvP split
enforceable in one place.

**4. Every remote is declared in `Shared/Network/Events.luau`,
validated by `Schemas.luau`, and rate-limited by `RateLimits.luau`.**
No ad-hoc remotes. A new remote without a schema is an exploit waiting to be
found.

**5. Nothing hard-codes a Studio-facing name.**
Tags, attributes, container names, collision groups, and attachment names come
from `Shared/Contract.luau`. Find world objects by tag and attribute, never by
path — authored and generated geometry have to be interchangeable.

**6. Config modules hold data, not state.**
Anything in `Shared/Config` is frozen data. Runtime state lives in services.

## Adding content

- **A weapon:** add a module under `Shared/Config/Weapons/`. The registry picks
  it up and rejects duplicate IDs at startup. Add it to `DefaultLoadout` to make
  it reachable in the slice.
- **A boss attack:** add a pattern to `StormEngine.Patterns` and an entry in
  `StormEngine.Attacks`. If it needs a new motion shape, add a builder to
  `ProjectilePattern` — and a determinism spec, which is enforced for every
  declared pattern.
- **An enemy:** add an entry to `Shared/Config/Enemies`.

## Tests

Specs live in `tests/` and run in-engine on every Studio play-test. Watch the
Output window for `[Tests] N passed`. Pure calculators and every client-to-server
payload validator are expected to have coverage.
