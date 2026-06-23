# Home Assistant ↔ Apple Home Matching Strategy

## Purpose

Compare Home Assistant's source-of-truth metadata with Apple Home's HomeKit inventory and produce a dry-run plan before any Apple Home mutation.

This is intentionally conservative: automatic matches are allowed only when confidence is high; ambiguous matches require a mapping file.

## Inputs

### Apple Home inventory

Read from the HomeKit helper:

- home name / ID
- room names / IDs
- accessory names / IDs
- accessory room assignment
- `isBridged`
- bridged child IDs/count
- services and characteristics

Only `isBridged=true` accessories are considered Home Assistant bridge candidates by default.

### Home Assistant inventory

Read from HA registries and states:

- area registry
- device registry
- entity registry
- current states for exposed domains, initially:
  - `light`
  - `cover`
  - later: `switch`, `fan`, `climate`, `sensor` if exposed intentionally

## Matching signals

Rank candidates using these signals, in order:

1. Explicit mapping file entry.
2. HomeKit bridge metadata if stable identifiers can be correlated.
3. Normalized accessory/entity friendly name.
4. Room/area agreement.
5. Domain/service type agreement, e.g. HomeKit light service ↔ HA `light`.
6. Device grouping hints, e.g. HA grouped light containing child entities.

Name-only matching is never enough for batch mutation. It can propose, not apply.

## Confidence bands

| Band | Meaning | Action |
|---|---|---|
| `matched` | high confidence, usually exact normalized name + domain and/or room agreement | include in dry-run plan |
| `review` | plausible but ambiguous, duplicate names, room mismatch, or grouped entity | require mapping file or human approval |
| `unmatched` | no reliable candidate | no action |

## Dry-run diff output

The diff should report:

- matched accessories
- ambiguous/review matches
- Apple Home accessories with no HA candidate
- HA entities with no Apple Home candidate
- room mismatches: Apple Home room vs HA area
- name mismatches: Apple Home display name vs HA friendly name
- proposed actions, all marked `dry_run: true`

Example action objects:

```json
{
  "dry_run": true,
  "action": "move_accessory",
  "home": "Example Home",
  "accessory": "Example Lamp",
  "from_room": "Living Room",
  "to_room": "Bedroom",
  "reason": "Matched HA entity is assigned to Bedroom"
}
```

## Mapping file rules

Use a checked-in example and a local untracked real mapping file.

Recommended files:

- `docs/samples/homekit-ha-mapping.example.yaml` — public example
- `local/homekit-ha-mapping.yaml` — real private mapping, ignored by git if it contains household-specific names/IDs

Mapping entries should prefer stable IDs where available, but may start with names during the prototype.

## Safety gates

- Matching and diff generation are read-only.
- No Apple Home changes happen during this task.
- Mutation tasks must require:
  1. exact target accessory/entity,
  2. dry-run output,
  3. explicit user approval,
  4. post-change verification,
  5. revert path for the first spike.
