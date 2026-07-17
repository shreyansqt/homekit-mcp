# Task 4 Checkpoint: Read-only Home Inventory Inspector

## Summary

The HomeKit helper now reads the real authorized Apple Home inventory and exposes it locally without mutating Apple Home.

## Added / verified

- Signed Mac Catalyst helper builds in the GUI user session.
- HomeKit access is authorized.
- The helper auto-selects the populated home when multiple homes are visible.
- `GET /inventory` returns all visible homes.
- `POST /mcp` accepts a home filter and returns only the requested home.
- Accessory inventory includes:
  - stable HomeKit identifier
  - display name
  - room name
  - category
  - reachable state
  - bridged status via `HMAccessory.isBridged`
  - bridged child IDs/count via `HMAccessory.bridgedAccessories`
  - services and characteristics
- Redacted real inventory sample: [`../samples/redacted-example-inventory.json`](../samples/redacted-example-inventory.json)

## Live verification

```text
Home access: authorized
selectedHomeName: Example Home
homeCount: 2
Example Home: 9 rooms, 24 accessories
```

Filtered MCP-style request:

```bash
curl -fsS -X POST http://127.0.0.1:8765/mcp \
  -H 'Content-Type: application/json' \
  -d '{"tool":"homekit_inventory","arguments":{"home":"Example Home"}}'
```

Result summary:

```text
selected=Example Home
homeCount=1
accessories=24
isBridged_true=23
bridge_accessories=1
```

## Tests

```text
Executed 4 tests, with 0 failures
** TEST SUCCEEDED **
```

## Notes

Most visible accessories in the selected home report `isBridged=true`, which is the key signal needed for matching Home Assistant HomeKit Bridge accessories. One accessory appears to be a bridge accessory containing bridged children.

No Apple Home mutations were performed.

## Next task

Compare this Apple Home inventory against Home Assistant areas/entities and produce a dry-run matching report.
