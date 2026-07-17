# HomeKit MCP Research

Research and product outline for a local Apple Home / HomeKit helper that can sync Apple Home metadata with Home Assistant and expose safe tools over MCP.

Status: research / viability assessment.

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
