# Task 5 Checkpoint: Home Assistant to Apple Home Matching Research

## Summary

A first read-only comparison pass was run between Home Assistant entity/area data and Apple Home bridged accessories.

No Apple Home or Home Assistant mutations were performed.

## Inputs checked

- Apple Home inventory from the local HomeKit helper.
- Home Assistant area registry.
- Home Assistant device registry.
- Home Assistant entity registry.
- Home Assistant current states for initial candidate domains:
  - `light`
  - `cover`

## Matching strategy

Documented in [`../matching-strategy.md`](../matching-strategy.md).

The proposed model uses:

1. explicit mapping file entries,
2. HomeKit bridged-accessory metadata,
3. normalized friendly names,
4. room/area agreement,
5. domain/service-type agreement,
6. manual review for duplicates and grouped entities.

## Sample files

- [`../samples/homekit-ha-mapping.example.yaml`](../samples/homekit-ha-mapping.example.yaml)
- [`../samples/redacted-dry-run-diff.json`](../samples/redacted-dry-run-diff.json)

## Live dry-run findings

The prototype dry-run found:

```text
Apple Home bridged accessories: 23
HA candidate entities: 38
Matched: 17
Needs review: 4
Unmatched Apple candidates: 2
Unmatched HA candidates: 17
```

Expected review cases appeared, especially:

- duplicate names such as generic "Hanging Lamp" in multiple rooms,
- grouped HA lights where one friendly entity represents several child lights,
- room/area mismatches that should be reviewed before any move proposal.

## Decision

Name + room + domain matching is useful enough to produce a reviewable dry-run, but not safe enough for automatic mutation.

The next implementation step should add a real dry-run command/tool that emits:

- confidence-ranked matches,
- ambiguous matches,
- proposed mapping-file additions,
- proposed room/name actions with `dry_run: true`.

## Safety status

Read-only only. No mutations performed.
