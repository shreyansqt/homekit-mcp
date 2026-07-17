# MCP Tool Surface

## Scope

This document defines the public MCP-facing contract for a local Apple Home / HomeKit helper. The first implementation is intentionally conservative: read-only tools are available first, and mutating tools must expose `dry_run`, `plan`, and `apply` modes.

The MCP server should wrap a local helper API owned by a HomeKit-authorized Mac Catalyst app. The helper is the only process that talks to HomeKit directly.

```text
MCP client
  -> local MCP server
  -> localhost helper API
  -> HomeKit-authorized helper app
  -> HomeKit framework
```

## Safety model

- Default mode is read-only.
- Mutating tools default to `plan` if no mode is supplied.
- `dry_run` and `plan` must not call HomeKit mutation APIs.
- `apply` requires an explicit confirmation flag and narrow target identifiers.
- Batch changes should go through a generated plan, not broad free-form instructions.
- Every successful apply should return before/after values suitable for an audit log.
- The server must bind to `127.0.0.1` only until a stronger local auth story exists.

Mutation mode values:

| Mode | Behavior |
|---|---|
| `dry_run` | Validate inputs and return the action that would be taken. No mutation. |
| `plan` | Return a stable plan object that can be reviewed and later applied. No mutation. |
| `apply` | Execute exactly the requested action only when `confirm_apply: true` is supplied. |

## Common request shape

The current helper prototype accepts a simple MCP-style HTTP bridge shape at `POST /mcp`:

```json
{
  "tool": "homekit_inventory",
  "arguments": {
    "home": "Example Home"
  }
}
```

The production MCP server can map Model Context Protocol `tools/call` requests to this shape while preserving the same names and argument schemas.

## Read-only tools

### `homekit_get_authorization_status`

Returns HomeKit authorization and selected-home state.

Arguments:

| Name | Type | Required | Notes |
|---|---:|---:|---|
| `home` | string | no | Optional home name filter. |

Response fields:

- `authorization`
- `selectedHomeName`
- `homeCount`
- `homes[].currentUserIsAdministrator`

### `homekit_list_homes`

Lists visible homes.

Arguments: none.

Response fields:

- `homes[].id`
- `homes[].name`
- `homes[].roomCount`
- `homes[].accessoryCount`
- `homes[].currentUserIsAdministrator`

### `homekit_list_rooms`

Lists rooms for one home.

Arguments:

| Name | Type | Required | Notes |
|---|---:|---:|---|
| `home` | string | no | Omit only when one home is visible. |

Response fields:

- `home`
- `rooms[].id`
- `rooms[].name`

### `homekit_list_accessories`

Lists accessories for one home, optionally filtered by room or bridged status.

Arguments:

| Name | Type | Required | Notes |
|---|---:|---:|---|
| `home` | string | no | Omit only when one home is visible. |
| `room` | string | no | Room name filter. |
| `bridged_only` | boolean | no | Defaults to `false`. |

Response fields:

- `accessories[].id`
- `accessories[].name`
- `accessories[].roomName`
- `accessories[].category`
- `accessories[].isReachable`
- `accessories[].isBridged`
- `accessories[].services[]`

### `homekit_get_accessory`

Returns one accessory by stable identifier, serial value, or exact name.

Arguments:

| Name | Type | Required | Notes |
|---|---:|---:|---|
| `home` | string | no | Home name filter. |
| `accessory` | string | yes | Accessory id, serial/entity id value, or exact name. |

### `homekit_diff_ha`

Compares Home Assistant source metadata with Apple Home inventory and returns proposed actions. This remains read-only.

Arguments:

| Name | Type | Required | Notes |
|---|---:|---:|---|
| `home` | string | no | Apple Home name filter. |
| `ha_inventory` | object | yes | HA areas/entities/devices snapshot from a higher-level integration. |
| `mapping` | object | no | Explicit entity-to-accessory mapping overrides. |

Response fields:

- `matched`
- `review`
- `unmatched_ha_entities`
- `unmatched_homekit_accessories`
- `proposed_actions[]`

Every proposed action should be marked `mode: "plan"` or `dry_run: true`.

## Mutating tools

### `homekit_move_accessory`

Moves exactly one accessory to one room.

Arguments:

| Name | Type | Required | Notes |
|---|---:|---:|---|
| `home` | string | yes | Home name. |
| `accessory_serial` | string | yes | Preferred stable HA entity id / HomeKit serial value. |
| `room` | string | yes | Target room name. |
| `mode` | string | no | `dry_run`, `plan`, or `apply`; defaults to `plan`. |
| `confirm_apply` | boolean | apply only | Must be `true` for `apply`. |

Dry-run / plan response:

```json
{
  "status": "planned",
  "tool": "homekit_move_accessory",
  "mode": "plan",
  "home": "Example Home",
  "accessory_serial": "light.example_lamp",
  "to_room": "Example Room"
}
```

Apply response adds `from_room` and confirms `status: "ok"`.

### `homekit_rename_accessory`

Renames exactly one accessory. Planned for the MCP contract; not implemented in the current helper skeleton.

Required modes and confirmation are identical to `homekit_move_accessory`.

### `homekit_create_room`

Creates one missing room. Planned for the MCP contract; not implemented in the current helper skeleton.

Required modes and confirmation are identical to `homekit_move_accessory`.

### `homekit_apply_plan`

Applies a reviewed plan produced by `homekit_diff_ha`.

Arguments:

| Name | Type | Required | Notes |
|---|---:|---:|---|
| `plan` | object | yes | Explicit reviewed plan object. |
| `confirm_apply` | boolean | yes | Must be `true`. |

This should remain disabled until single-action apply has been tested and audited.

## Prototype implementation status

The current Mac Catalyst helper already exposes:

- `GET /health`
- `GET /inventory`
- `GET /`
- `POST /mcp` with `homekit_inventory`-style inventory filtering
- guarded mutation skeleton for `homekit_move_accessory`

The server skeleton should continue to treat read-only inventory as the first-class path. Mutation routes may exist, but must return plans unless explicitly called with `mode: "apply"` and `confirm_apply: true`.
