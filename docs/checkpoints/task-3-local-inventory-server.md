# Task 3 Checkpoint: Read-only Local HomeKit Inventory Server

## Summary

The HomeKit helper now runs a localhost-only read-only server from the Catalyst app.

This keeps the app shape boring: launch helper, grant Apple Home access, then agents query localhost. No menu bar machinery.

## Added

- Full read-only inventory JSON model:
  - homes
  - rooms
  - accessories
  - services
  - characteristics
  - authorization status
  - generation timestamp
- Local TCP HTTP server on `127.0.0.1:8765`.
- Endpoints:
  - `GET /health` → server health.
  - `GET /` → server metadata and advertised tool name.
  - `GET /inventory` → Apple Home inventory JSON.
  - `POST /mcp` → currently returns the same inventory JSON as a simple MCP-style bridge stub.
- UI status rows for server state and localhost URL.
- Entitlements file now includes:
  - `com.apple.developer.homekit`
  - `com.apple.security.network.server`
- Unit tests for inventory JSON and HTTP response handling.

## Verification performed

### Regenerate project

```bash
cd apps/helper-catalyst
xcodegen generate
```

Result:

```text
Created project at apps/helper-catalyst/HomeKitMCPHelper.xcodeproj
```

### Build and tests

```bash
cd apps/helper-catalyst
xcodebuild \
  -project HomeKitMCPHelper.xcodeproj \
  -scheme HomeKitMCPHelper \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Result:

```text
Executed 3 tests, with 0 failures
** TEST SUCCEEDED **
```

### Actual localhost smoke test

Launched the built app executable from DerivedData, then queried localhost.

```bash
curl -fsS http://127.0.0.1:8765/health
```

Result:

```json
{"status":"ok"}
```

```bash
curl -fsS http://127.0.0.1:8765/
```

Result:

```json
{"name":"HomeKit MCP Helper","tools":["homekit_inventory"],"endpoints":{"health":"/health","inventory":"/inventory","mcp":"/mcp"}}
```

```bash
python3 - <<'PY'
import json, urllib.request
raw = urllib.request.urlopen('http://127.0.0.1:8765/inventory', timeout=5).read().decode()
obj=json.loads(raw)
print('keys=', sorted(obj.keys()))
print('homeCount=', obj.get('homeCount'))
print('authorization=', obj.get('authorization'))
print('homes_type=', type(obj.get('homes')).__name__)
PY
```

Result:

```text
keys= ['authorization', 'generatedAt', 'homeCount', 'homes']
homeCount= 0
authorization= Home access: not determined
homes_type= list
```

## Current blocker

The server and inventory shape work. Real Apple Home enumeration still requires launching a signed app and granting Home permission.

Unsigned launch smoke test reports:

```text
authorization= Home access: not determined
homeCount= 0
```

That is expected until the app is signed with a development team and macOS grants HomeKit access.

## Next checkpoint

Configure signing/development team, launch the app normally, approve Apple Home access, then rerun:

```bash
curl -fsS http://127.0.0.1:8765/inventory
```

Expected success criterion: non-empty real Apple Home inventory or an authorized empty home list if Apple Home is genuinely empty.
