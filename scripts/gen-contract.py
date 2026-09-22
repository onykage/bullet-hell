#!/usr/bin/env python3
"""
Generates docs/INTEGRATION_CONTRACT.md from Shared/Contract.luau.

The contract is the handoff document between the code workstream and the Studio
workstream. Writing it by hand guarantees it goes stale the first time someone
renames a tag, so it is generated from the module the code actually reads.
Run `make contract` after changing Contract.luau.
"""
import re
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "src/ReplicatedStorage/Shared/Contract.luau"
OUTPUT = ROOT / "docs/INTEGRATION_CONTRACT.md"


def block(name: str, text: str) -> str:
    """Extract the body of a `Contract.<name> = { ... }` assignment."""
    start = text.index(f"Contract.{name} = {{")
    depth, index = 0, text.index("{", start)
    for position in range(index, len(text)):
        if text[position] == "{":
            depth += 1
        elif text[position] == "}":
            depth -= 1
            if depth == 0:
                return text[index + 1:position]
    raise ValueError(f"unterminated table for Contract.{name}")


def pairs(body: str):
    """Yield (key, value) for simple `Key = "value",` entries."""
    for key, value in re.findall(r'(\w+)\s*=\s*"([^"]*)"', body):
        yield key, value


def attribute_map(body: str):
    """Yield (tag_key, [attribute names]) for the Attributes table."""
    for tag_key, values in re.findall(
        r"\[Contract\.Tags\.(\w+)\]\s*=\s*\{([^}]*)\}", body
    ):
        yield tag_key, re.findall(r'"([^"]+)"', values)


def main() -> int:
    text = SOURCE.read_text()

    tags = dict(pairs(block("Tags", text)))
    attributes = dict(attribute_map(block("Attributes", text)))
    containers = dict(pairs(block("Containers", text)))
    groups = dict(pairs(block("CollisionGroups", text)))
    attachments = dict(pairs(block("WeaponAttachments", text)))
    markers = dict(pairs(block("Markers", text)))
    content_id = re.search(r'Contract\.ContentIdAttribute = "(\w+)"', text).group(1)

    out = [
        "# Integration Contract",
        "",
        "**Generated from `src/ReplicatedStorage/Shared/Contract.luau`. Do not edit by hand —",
        "run `make contract`.**",
        "",
        "This is the complete set of names shared between the code workstream and the",
        "Roblox Studio workstream. Changing any value here is a contract change: update",
        "the module, regenerate this file, tell the other workstream, and re-run the",
        "affected integration milestone (design doc, *Change-control rule*).",
        "",
        "## Tagged Instances",
        "",
        f"Every tagged gameplay object also carries a stable `{content_id}` attribute that is",
        "never reused for different content.",
        "",
        "| Purpose | CollectionService tag | Required attributes |",
        "|---|---|---|",
    ]

    for key, tag in tags.items():
        required = attributes.get(key, [])
        cells = ", ".join(f"`{name}`" for name in required) or "—"
        label = re.sub(r"(?<!^)(?=[A-Z])", " ", key)
        out.append(f"| {label} | `{tag}` | {cells} |")

    out += [
        "",
        "## Required Workspace containers",
        "",
        "These Folders must exist and keep these names. The code creates any that are",
        "missing at boot, so an empty place still runs, but authored content must live",
        "in the right one to be found.",
        "",
        "| Container | Holds |",
        "|---|---|",
    ]

    holds = {
        "World": "All authored world geometry",
        "ArenaEntrances": "Arena entrance landmarks",
        "SpawnVolumes": "Enemy spawn volumes",
        "ZoneVolumes": "Zone rule volumes",
        "EncounterMarkers": "Boss spawns, attack origins, conductors, arena spawns",
        "NavigationMarkers": "Jump links, cover hints, restricted paths",
        "Interactables": "Vendors, pickups, prompts",
        "Runtime": "Code-owned, never authored, never saved",
    }
    for key, name in containers.items():
        out.append(f"| `{name}` | {holds.get(key, '')} |")

    out += [
        "",
        "## Collision groups",
        "",
        "Registered by `CollisionGroupService` at boot, so the place file and the code",
        "cannot disagree about which groups exist.",
        "",
        "| Group | Notes |",
        "|---|---|",
    ]
    notes = {
        "Player": "Players do not collide with each other",
        "Enemy": "Enemies do not collide with each other",
        "Projectile": "Cosmetic only — collides with nothing",
        "Viewmodel": "First-person weapon; never collides or blocks a ray",
        "WorldProp": "Static authored geometry",
        "SafeZoneBarrier": "Blocks damage in both directions",
        "Debris": "Short-lived physical effects",
    }
    for key, name in groups.items():
        out.append(f"| `{name}` | {notes.get(key, '')} |")

    out += [
        "",
        "## Weapon model attachments",
        "",
        "Every weapon model supplied by the Studio workstream needs these attachment",
        "points, spelled exactly like this.",
        "",
        "| Attachment | Purpose |",
        "|---|---|",
    ]
    purposes = {
        "Muzzle": "Tracer origin, muzzle flash",
        "AimPoint": "Aligned to screen centre when aiming",
        "LeftHandGrip": "Off-hand IK target",
        "Magazine": "Reload animation detach point",
        "CasingEject": "Shell ejection origin",
    }
    for key, name in attachments.items():
        out.append(f"| `{name}` | {purposes.get(key, '')} |")

    out += [
        "",
        "## Storm Engine arena markers",
        "",
        "Parts tagged `BossMarker` or `AttackOrigin` with `ArenaId = \"storm_engine_arena\"`",
        "and the `MarkerId` values below. The code looks markers up by tag and attribute,",
        "never by path, so generated and authored geometry are interchangeable.",
        "",
        "| MarkerId | Purpose |",
        "|---|---|",
    ]
    marker_purposes = {
        "BossSpawn": "Where the boss is placed and where self-centred patterns originate",
        "PlayerSpawn": "Party arrival points (also needs `SpawnType = \"Arena\"`)",
        "ArenaCenter": "Reference point for arena-relative logic",
        "ReturnPoint": "Where players are sent on completion or wipe",
    }
    for key, name in markers.items():
        out.append(f"| `{name}` | {marker_purposes.get(key, '')} |")

    out += [
        "",
        "Additionally: `AttackOrigin1`–`AttackOrigin4` (tag `AttackOrigin`) and",
        "`Conductor1`–`Conductor4` (tag `BossConductor`).",
        "",
        "## How to replace the graybox",
        "",
        "`WorldBuilderService` generates the blockout **only** when `Workspace.World` is",
        "empty. Commit authored geometry into that container with these tags and",
        "attributes and the generator stops on its own — no flag to flip, no code change.",
        "Set the `GrayboxDisabled` attribute on `Workspace` to force it off regardless.",
        "",
    ]

    OUTPUT.write_text("\n".join(out))
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
