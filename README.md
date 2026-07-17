# HomeKit MCP Research

Research and product outline for a local Apple Home / HomeKit helper that can sync Apple Home metadata with Home Assistant and expose safe tools over MCP.

Status: research / viability assessment. The tracked files are sanitized for public review: examples use placeholder home/device names and the Xcode project does not include a personal Apple developer team ID.

## Local helper and CLI

The Mac Catalyst helper lives in [`App/HomeKitMCPHelper`](App/HomeKitMCPHelper). It exposes a localhost-only HTTP API while running:

- `GET /health`
- `GET /inventory`
- `POST /mcp`

Use the Python standard-library CLI wrapper in [`bin/homekit-mcp`](bin/homekit-mcp):

```bash
bin/homekit-mcp health
bin/homekit-mcp inventory
bin/homekit-mcp inventory --home "Example Home"
bin/homekit-mcp mcp --json '{"tool":"homekit_inventory","arguments":{"home":"Example Home"}}'
```

See [`cli/README.md`](cli/README.md) for detailed usage, including mutation planning/apply examples.

## Local configuration

Copy `.env.example` to `.env` for local-only shell settings if desired. Do not commit `.env` or real Apple developer team IDs. For signed local builds, pass your own team ID to `xcodebuild` or set it in Xcode locally:

```bash
cd App/HomeKitMCPHelper
xcodebuild \
  -project HomeKitMCPHelper.xcodeproj \
  -scheme HomeKitMCPHelper \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  DEVELOPMENT_TEAM=YOURTEAMID \
  build
```

## Documents

- [`docs/research.md`](docs/research.md) — HomeKit API capability research and limitations.
- [`docs/product-outline.md`](docs/product-outline.md) — proposed architecture, MVP, MCP tools, and open questions.
- [`docs/prototype-plan.md`](docs/prototype-plan.md) — gated prototype plan, acceptance tests, permissions, and safety checkpoints.
- [`docs/matching-strategy.md`](docs/matching-strategy.md) — Home Assistant ↔ Apple Home matching and dry-run diff design.
- [`docs/mcp-tool-surface.md`](docs/mcp-tool-surface.md) — MCP tool schemas, read-only-first contract, and mutation dry-run/plan/apply rules.

## Checkpoints

- [`docs/checkpoints/task-2-catalyst-helper.md`](docs/checkpoints/task-2-catalyst-helper.md) — Mac Catalyst helper proof-of-life checkpoint.
- [`docs/checkpoints/task-3-local-inventory-server.md`](docs/checkpoints/task-3-local-inventory-server.md) — localhost read-only inventory server checkpoint.
- [`docs/checkpoints/task-4-read-only-inventory-inspector.md`](docs/checkpoints/task-4-read-only-inventory-inspector.md) — real authorized Apple Home inventory checkpoint.
- [`docs/checkpoints/task-5-ha-homekit-matching.md`](docs/checkpoints/task-5-ha-homekit-matching.md) — Home Assistant to Apple Home matching dry-run checkpoint.
