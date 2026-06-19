# Prototype Plan and Acceptance Tests

## Purpose

Validate whether a Mac-based HomeKit helper can safely inspect and organize Apple Home metadata for Home Assistant bridged accessories, then expose that capability through MCP.

This prototype is intentionally narrow. It proves the HomeKit permission, inventory, matching, and one reversible mutation path before building a larger product.

## Guiding principles

1. **Native first** — use standard Apple UI patterns and controls.
2. **Menu bar app shape** — the user-facing surface should be lightweight, familiar, and always reachable.
3. **Home Assistant remains source of truth** for automation metadata where practical.
4. **Apple Home metadata is changed only through official HomeKit APIs.**
5. **Dry-run before mutation** — structural changes must be visible before they are applied.
6. **Small reversible tests** — prove one accessory move/rename before batch sync.
7. **Audit every mutation** — record what changed, when, and whether it was reverted.
8. **No private Apple frameworks in the MVP.**

## Prototype phases

### Phase 1 — Build and permission proof

Goal: confirm a Mac Catalyst app can compile, launch, request HomeKit access, and report authorization status.

Acceptance tests:

- App builds locally on the target Mac.
- App launches as a menu bar app or minimal Catalyst app.
- App includes HomeKit capability and `NSHomeKitUsageDescription`.
- App can instantiate `HMHomeManager`.
- App shows one of:
  - Home access granted.
  - Home access denied.
  - Home access not determined / prompt needed.
- If blocked, the exact Xcode signing, entitlement, or permission error is documented.

Manual checkpoint:

- User grants or denies Home access in the system prompt.
- No Apple Home mutations happen in this phase.

### Phase 2 — Read-only Apple Home inventory

Goal: enumerate Apple Home structure without changing anything.

Acceptance tests:

- App lists visible homes.
- App lists rooms for the selected home.
- App lists accessories and services.
- App includes each accessory's:
  - Display name.
  - Room name.
  - Reachable state, if available.
  - Bridged status, if available.
  - Service names/types.
- App exports a redacted JSON inventory sample for development.
- No room, accessory, service group, or scene is modified.

Manual checkpoint:

- User reviews whether the visible inventory matches Apple Home.
- User confirms whether Home Assistant bridged accessories appear in the inventory.

### Phase 3 — Home Assistant comparison and matching

Goal: compare Home Assistant's areas/entities against Apple Home rooms/accessories.

Acceptance tests:

- Tool can read Home Assistant areas/entities through HA REST/WebSocket APIs.
- Tool can read Apple Home inventory from the helper.
- Tool produces a dry-run diff with:
  - Apple Home rooms missing for HA areas.
  - Accessories that appear to be in the wrong Apple Home room.
  - Name mismatches.
  - Unmatched Home Assistant entities.
  - Unmatched Apple Home accessories.
  - Ambiguous matches that require user mapping.
- Tool supports a mapping file for manual overrides.
- No Apple Home mutations happen in this phase.

Manual checkpoint:

- User reviews proposed matching strategy.
- User approves one test accessory for the mutation spike.

### Phase 4 — Single reversible mutation

Goal: prove one official HomeKit metadata change and revert it.

Allowed test options:

1. Move one selected accessory from Room A to Room B, then move it back.
2. Rename one selected accessory to a temporary name, then rename it back.
3. Create a temporary test room, move one accessory into it, then restore and delete the room.

Acceptance tests:

- User explicitly approves the exact accessory and test mutation.
- App performs the mutation through HomeKit APIs.
- App verifies the new state by re-reading HomeKit inventory.
- App reverts the change.
- App verifies the original state was restored.
- Audit log records before/after/revert results.

Manual checkpoint:

- User confirms Apple Home still looks correct.
- If successful, project can proceed to MCP and batch planning.

### Phase 5 — MCP read-only server prototype

Goal: expose the helper's read-only capabilities to MCP clients.

Acceptance tests:

- MCP server starts locally.
- MCP server can call the helper through the chosen IPC mechanism.
- Read-only tools work:
  - `homekit_get_authorization_status`
  - `homekit_list_homes`
  - `homekit_list_rooms`
  - `homekit_list_accessories`
  - `homekit_diff_ha`
- Mutating tools are either absent or hard-disabled behind explicit plan/apply semantics.

Manual checkpoint:

- User reviews tool names and returned data shape.

### Phase 6 — MCP mutation plan/apply prototype

Goal: expose safe, narrow mutation tools.

Acceptance tests:

- Mutating operations require an explicit plan ID or exact target IDs.
- Mutating operations support dry-run.
- Batch apply requires explicit confirmation.
- Audit log is written for every attempted mutation.
- Failed mutations report partial progress and do not hide errors.

Manual checkpoint:

- User decides whether this should remain private, be opened as a public project, or continue as an internal helper.

## Permissions and setup checklist

Required:

- Apple Developer/Xcode environment capable of building Mac Catalyst apps.
- HomeKit capability enabled for the app target.
- Entitlement: `com.apple.developer.homekit`.
- `NSHomeKitUsageDescription` in app `Info.plist`.
- User grants Home access when prompted.
- The signed-in Apple ID must have sufficient Home permissions to inspect and modify the target Home.

Recommended:

- Launch-at-login disabled during early prototype.
- Mutations disabled by default.
- Local logs stored outside source control.
- Redacted sample inventory committed only after removing personal names/IDs.

## Safety gates

| Gate | Required before proceeding |
|---|---|
| Build gate | App compiles and launches locally. |
| Permission gate | User grants HomeKit access or blocker is documented. |
| Inventory gate | Read-only Apple Home inventory matches what the user expects. |
| Matching gate | Dry-run HA vs Apple Home diff is understandable and mostly correct. |
| Mutation gate | User selects one safe accessory and approves the exact reversible operation. |
| MCP gate | Read-only tools work before any mutating MCP tool exists. |
| Batch gate | Batch changes require plan review and explicit apply. |

## Initial implementation recommendation

Start with the smallest useful native app:

- Swift / SwiftUI / Mac Catalyst.
- Menu bar extra or minimal menu bar-style UI.
- HomeKit permission/status view.
- Selected Home picker.
- Read-only inventory button.
- Export redacted JSON inventory button.
- Local audit log viewer.

Only after the inventory path works should the project add:

- Home Assistant comparison.
- Mapping file support.
- Reversible mutation.
- MCP server.

## Stop conditions

Stop and ask for user feedback if any of these happen:

- HomeKit entitlement cannot be enabled locally.
- App cannot import/use HomeKit under Mac Catalyst.
- User denies Home permission.
- Inventory does not show Home Assistant bridged accessories.
- Matching is ambiguous for the proposed test accessory.
- Any mutation fails to revert cleanly.

## Definition of prototype success

The prototype is successful if:

1. A native-feeling Mac helper can access Apple Home with user permission.
2. It can list rooms/accessories and identify bridged accessories.
3. It can compare Apple Home organization with Home Assistant metadata.
4. It can perform and revert one safe HomeKit metadata change.
5. The capability can be exposed to an MCP client with read-only tools first and mutating tools behind explicit plan/apply gates.
