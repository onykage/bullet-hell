# ADR 0002 — The graybox world is generated behind the Studio contract

**Status:** Accepted, Milestone 1
**Context:** The code and Studio workstreams run in parallel (design doc,
"Workstream ownership"), and Milestone 1 must be playable before any geometry
is authored.

## Decision

`WorldBuilderService` generates the hub, firing range, and Storm Engine arena
from primitives at runtime — but tags and attributes every object exactly as
the integration contract specifies. Services locate markers by
`CollectionService` tag plus `ArenaId`/`MarkerId` attributes, never by path.

The generator runs only when `Workspace.World` is empty, or is disabled by a
`GrayboxDisabled` attribute on `Workspace`.

## Alternatives rejected

**Wait for authored geometry.** The combat, boss, and movement work cannot be
evaluated without a space to evaluate it in, and blocking the whole code
workstream on an art handoff inverts the dependency the design document
deliberately sets up.

**Generate geometry without the contract.** Faster to write and throws away
every line the moment real geometry lands, including the marker-lookup code,
which is the part most likely to contain bugs.

## Consequences

Good:
- The slice is playable today with `make build` and nothing else.
- The contract is exercised continuously rather than being an untested document.
  `Graybox.mark` asserts that every required attribute is present, so a contract
  violation is a startup failure with a named instance, not a runtime mystery.
- Handoff is a drop-in: the Studio team commits geometry into `Workspace.World`
  and the generator stops on its own.

Costs:
- The graybox is not a scale reference for art. Dimensions in
  `StormEngine.Graybox` were chosen for gameplay spacing, and the Studio
  workstream should treat them as gameplay constraints to build around, not as
  a blockout to decorate.
- Two code paths exist in principle (generated and authored) though only one
  runs. The shared tag-lookup layer keeps that from becoming two behaviours.
