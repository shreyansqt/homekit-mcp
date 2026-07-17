# HomeKit MCP Helper CLI

`bin/homekit-mcp` is a small Python 3 wrapper for the local HomeKit MCP Helper HTTP API.
It talks to the helper on `http://127.0.0.1:8765` by default and uses only the Python standard library.

## Prerequisites

1. Build and run `apps/helper-catalyst` on the same Mac.
2. Grant Apple Home permission when macOS prompts.
3. Confirm the helper shows the localhost server as running.

Set `HOMEKIT_MCP_BASE_URL` or pass `--base-url` if you use a different local endpoint.

## Usage

```bash
# Health check
bin/homekit-mcp health

# Full inventory from GET /inventory
bin/homekit-mcp inventory

# Filter by home name through POST /mcp
bin/homekit-mcp inventory --home "Example Home"

# Raw/complete MCP-style JSON body
bin/homekit-mcp mcp --json '{"tool":"homekit_inventory","arguments":{"home":"Example Home"}}'

# Build a MCP request from a tool and KEY=VALUE arguments
bin/homekit-mcp mcp \
  --tool homekit_move_accessory \
  --arg home='"Example Home"' \
  --arg accessory_serial='"light.example_floor_lamp"' \
  --arg room='"Guest Room"' \
  --arg mode='"plan"'
```

`KEY=VALUE` values are parsed as JSON when possible, so booleans and objects can be passed without string coercion:

```bash
bin/homekit-mcp mcp \
  --tool homekit_move_accessory \
  --arg home='"Example Home"' \
  --arg accessory_serial='"light.example_floor_lamp"' \
  --arg room='"Guest Room"' \
  --arg mode='"apply"' \
  --arg confirm_apply=true
```

The helper defaults supported mutations to `plan`; applying a mutation requires both `mode: "apply"` and `confirm_apply: true`.
