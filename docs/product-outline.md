# Product Outline: HomeKit MCP Helper

## Working name

`homekit-mcp-helper`

## Problem

Home Assistant can act as the automation source of truth, while Apple Home remains the household-facing interface used on iPhone, iPad, and Mac.

Home Assistant's HomeKit Bridge syncs device state/control, but Apple Home metadata often still needs manual maintenance:

- Room assignment.
- Accessory display names.
- Grouping/service-group decisions.
- Scene/action-set mirroring.
- Detecting missing or stale bridged accessories.

An automation agent should be able to perform these admin tasks once, safely, across both systems.

## Product goal

Build a local Mac helper that gives automation clients a safe, permissioned way to inspect and modify Apple Home organization while keeping Home Assistant as the source of truth.

## Non-goals

- Replacing Home Assistant.
- Replacing Apple's Home app.
- Exposing Apple Home controls to every agent by default.
- Using private Apple frameworks in the MVP.
- Building cloud infrastructure.
- Day-to-day light control; this project focuses on administration and metadata sync.

## Architecture

```text
MCP host / automation client
  -> MCP client
  -> local MCP server process
  -> authenticated local IPC
  -> Catalyst HomeKit Helper app
  -> HomeKit framework
  -> Apple Home / iCloud Home

Home Assistant
  -> REST/WebSocket API
  -> desired source-of-truth metadata
```

Two implementation options:

### Option A: Catalyst app embeds MCP server

The Catalyst app itself runs a local MCP server.

Pros:

- Single process with HomeKit entitlement.
- Simpler permission model.
- Fewer IPC pieces.

Cons:

- MCP server lifecycle tied to GUI app lifecycle.
- Catalyst app needs to be running.
- More complexity inside the app target.

### Option B: Catalyst app exposes local API; separate MCP server wraps it

The Catalyst app holds HomeKit permission and exposes a localhost/XPC/App Group API. A separate Node/Python/Swift MCP server talks to the app.

Pros:

- Clean MCP implementation in normal tooling.
- GUI permission app stays small.
- Easier to test MCP separately.

Cons:

- Must secure the local API.
- More moving parts.

Recommended MVP: **Option B**, unless HomeKit calls fail outside foreground app lifecycle expectations.

## Security model

- Bind local API to `127.0.0.1` only, or use XPC/App Group where possible.
- Require a local auth token generated on first launch and stored in Keychain.
- MCP server access should be explicitly configured for trusted local clients only.
- Mutating tools should support dry-run mode.
- Dangerous operations require narrow parameters, never broad free-form commands.
- Log every mutation with before/after values.

## Source of truth model

Home Assistant remains source of truth for:

- Entity IDs.
- Areas.
- Friendly names, where appropriate.
- Exposure choices.
- Device/entity registry metadata.

Apple Home stores:

- HomeKit accessory identity after pairing.
- Apple Home room assignment.
- Apple Home display name after pairing.
- HomeKit scenes/action sets.
- Home-specific grouping metadata.

The helper should compute diffs, not blindly overwrite.

## Matching strategy: HA entity -> Apple Home accessory

Potential matching signals:

1. Accessory name / service name from HA HomeKit Bridge.
2. HomeKit bridge name / manufacturer/model metadata.
3. Stable HA entity name from HomeKit Bridge configuration.
4. Accessory serial/unique identifiers exposed through HomeKit metadata, if available.
5. User-maintained mapping file for ambiguous cases.

MVP should include a mapping file because name-only matching will eventually bite us. It always does.

Example mapping:

```yaml
homekit_home: Home
mappings:
  light.bedroom_side_lamp_left:
    homekit_accessory_name: Bedroom Side Lamp Left
    desired_room: Bedroom
  light.bedroom_hanging_lamp:
    homekit_accessory_name: Bedroom Hanging Lamp
    desired_room: Bedroom
```

## Proposed MCP tools

### Read-only tools

#### `homekit_get_authorization_status`

Returns whether the helper has HomeKit access.

#### `homekit_list_homes`

Lists homes visible to the authorized Apple ID.

#### `homekit_list_rooms`

Input: optional `home_id` or home name.

Returns room IDs/names and accessory counts.

#### `homekit_list_accessories`

Inputs:

- `home_id` / home name.
- Optional room filter.
- Optional `bridged_only` boolean.

Returns accessories, room assignment, services, reachable state, bridged metadata.

#### `homekit_get_accessory`

Returns detail for one accessory.

#### `homekit_list_service_groups`

Lists HomeKit service groups and services contained.

#### `homekit_list_action_sets`

Lists HomeKit scenes/action sets.

#### `homekit_diff_ha`

Compares Home Assistant areas/names/exposed entities to Apple Home rooms/accessories.

Returns:

- Missing Apple Home rooms.
- Accessories in wrong room.
- Name mismatches.
- Unmatched HA entities.
- Unmatched Apple Home accessories.
- Proposed actions.

Must support `dry_run: true`.

### Mutating tools

#### `homekit_create_room`

Creates a room if absent.

Inputs:

- `home`
- `room_name`

#### `homekit_rename_room`

Renames a room.

Inputs:

- `home`
- `room_id` or current name.
- `new_name`.

#### `homekit_move_accessory`

Assigns an accessory to a room.

Inputs:

- `home`
- `accessory_id` or matched name.
- `room_id` or room name.

#### `homekit_rename_accessory`

Renames an accessory.

Inputs:

- `home`
- `accessory_id` or matched name.
- `new_name`.

#### `homekit_create_service_group`

Creates a HomeKit service group.

Inputs:

- `home`
- `group_name`
- `service_ids`.

#### `homekit_apply_plan`

Applies a previously generated diff plan.

Inputs:

- `plan_id` or full plan object.
- `confirm: true`.

This should be the preferred mutation path for larger changes.

### HA-aware orchestration tools

These may live in a higher-level orchestration layer instead of the HomeKit MCP server, but are useful to define.

#### `sync_homekit_from_ha_areas`

Reads HA areas/entities, compares to Apple Home, and applies room moves.

#### `sync_homekit_names_from_ha`

Compares HA friendly names to Apple Home accessory names and proposes renames.

#### `sync_homekit_after_new_accessory`

Given a HA entity/device, find its Apple Home bridged accessory and place it correctly.

## MVP scope

1. Catalyst helper app with HomeKit permission.
2. Read-only inspector:
   - homes
   - rooms
   - accessories
   - bridged status
3. Local API between helper and MCP server.
4. MCP server exposing read-only tools.
5. HA comparison script/tool generating a dry-run diff.
6. One safe mutation: move one accessory to one room.
7. Audit log.

## Phase 2

- Create missing rooms.
- Rename accessories.
- Batch apply room-assignment plan.
- YAML mapping file for entity/accessory matching.
- Better bridge/accessory detection for HA HomeKit Bridge.
- Service group experiments.
- Scene/action-set experiments.

## Phase 3

- Full sync command with approval gates.
- UI showing diff before apply.
- Signed/notarized app.
- Launch at login.
- Generic MCP client configuration examples.

## Key risks

| Risk | Severity | Mitigation |
|---|---:|---|
| HomeKit unavailable in native macOS CLI | High | Use Mac Catalyst app |
| User permission denied/revoked | Medium | Explicit status tool + setup UI |
| Accessory matching ambiguity | High | Mapping file + dry-run diff |
| Apple Home caches HA bridge names | Medium | Rename through HomeKit where possible; avoid HA entity ID churn |
| Service grouping does not match Home app UI grouping | Medium | Treat grouping as experimental |
| Background app lifecycle limits | Medium | Test Catalyst foreground/background behavior early |
| Private API temptation | High | Avoid for MVP |

## Research questions to answer with a prototype

1. Can a Catalyst app on this Mac enumerate the user's actual Apple Home rooms/accessories?
2. Do Home Assistant HomeKit Bridge accessories report useful stable identifiers for matching?
3. Can the app move a bridged HA accessory between Apple Home rooms reliably?
4. Can the app rename a bridged HA accessory reliably?
5. How does Apple Home display `HMServiceGroup` changes?
6. Can the helper run at login and serve requests while not foregrounded?
7. What is the cleanest local IPC: localhost HTTP, XPC, or App Group file/socket?

## Recommendation

Proceed with a prototype, not a full product yet.

Prototype acceptance criteria:

- User grants Home access once.
- Helper lists Apple Home rooms/accessories.
- Helper identifies at least one HA-bridged accessory.
- An MCP client can call one tool to dry-run a Home Assistant vs Apple Home room diff.
- An MCP client can move one test accessory to a chosen Apple Home room and verify it.

If those pass, the project is viable.
