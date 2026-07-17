# HomeKit MCP

Local Apple Home / HomeKit helper research prototype. The project explores a Mac helper that can inspect Apple Home metadata, compare it with Home Assistant naming/room data, and expose safe read-first tools over an MCP-style local interface.

Status: prototype / public-readiness review. Tracked files are sanitized for public review: examples use placeholder home/device names, localhost URLs only, and no personal Apple developer team ID or signing identity is checked in.

## Repository layout

```text
apps/
  helper-catalyst/   Mac Catalyst app that owns HomeKit permission and localhost API
  menubar/           Native AppKit menu-bar wrapper for the helper
bin/homekit-mcp      Python standard-library CLI for the helper API
cli/README.md        CLI usage examples
docs/                Research notes, tool-surface design, checkpoints, and sanitized samples
```

## Apps

The Mac Catalyst helper lives in [`apps/helper-catalyst`](apps/helper-catalyst). It owns all HomeKit access and exposes a localhost-only HTTP API while running:

- `GET /health`
- `GET /inventory`
- `POST /mcp`

The native macOS menu-bar wrapper lives in [`apps/menubar`](apps/menubar). It is an `LSUIElement` AppKit status item that keeps HomeKit access in the Catalyst helper, reads health/inventory from `http://127.0.0.1:8765`, opens the helper window, refreshes status, restarts the helper LaunchAgent, and quits only the wrapper.

Both app directories keep their own XcodeGen `project.yml` as source of truth. Checked-in `.xcodeproj` files are generated from those specs for convenience.

## CLI

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
cd apps/helper-catalyst
xcodebuild \
  -project HomeKitMCPHelper.xcodeproj \
  -scheme HomeKitMCPHelper \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  DEVELOPMENT_TEAM=YOURTEAMID \
  build
```

## Build and test

Regenerate Xcode projects after changing `project.yml` files:

```bash
(cd apps/helper-catalyst && xcodegen generate)
(cd apps/menubar && xcodegen generate)
```

Unsigned local verification:

```bash
(cd apps/helper-catalyst && xcodebuild -project HomeKitMCPHelper.xcodeproj -scheme HomeKitMCPHelper -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO test)
(cd apps/menubar && xcodebuild -project HomeKitMCPMenuBar.xcodeproj -scheme HomeKitMCPMenuBar -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test)
python3 -m py_compile bin/homekit-mcp
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
