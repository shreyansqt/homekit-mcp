# Apple Home / HomeKit Programmatic Management Research

## Goal

Determine whether Jarvis can manage Apple Home metadata — rooms, accessory names, grouping, and Home Assistant bridged accessories — without manually clicking through the Home app.

The use case is not day-to-day device control. It is **home administration sync**:

- Add accessory in Home Assistant.
- Expose it through HomeKit Bridge.
- Place/rename/group it correctly in Apple Home.
- Keep Apple Home usable for iPhone/Mac users.

## Executive summary

This is viable, but not as a simple native macOS CLI.

The official route is a **Mac Catalyst app with the HomeKit entitlement**. That app can request Home access from the user, use the HomeKit framework, and expose a local IPC/API surface that an MCP server can wrap for Jarvis.

Recommended architecture:

```text
Jarvis / Hermes
  -> MCP tools
  -> local MCP server
  -> localhost/XPC/App Group bridge
  -> Mac Catalyst HomeKit Helper app
  -> HomeKit framework
  -> Apple Home / iCloud Home data
```

## Official API surface

Apple's public HomeKit framework exposes enough for this project.

Relevant classes:

- `HMHomeManager`
  - Lists homes.
  - Tracks primary home.
  - Reports authorization status.
- `HMHome`
  - Lists accessories, rooms, zones, service groups, action sets.
  - Creates/removes rooms.
  - Assigns accessories to rooms.
  - Creates/removes zones.
  - Creates/removes service groups.
  - Creates action sets/scenes.
- `HMAccessory`
  - Reads accessory name, services, room, reachable state, bridged status.
  - Renames accessories with `updateName`.
  - Detects bridge relationships with `isBridged` / `bridgedAccessories`.
- `HMRoom`
  - Reads/renames room names.
  - Lists accessories in the room.
- `HMZone`
  - Groups rooms; can be renamed and assigned rooms.
- `HMServiceGroup`
  - Groups services, not necessarily whole accessories.
- `HMActionSet`
  - HomeKit scenes/action sets.

Important operations for our goal:

| Need | HomeKit support | Notes |
|---|---:|---|
| List homes | Yes | `HMHomeManager.homes` |
| List rooms | Yes | `HMHome.rooms` |
| Create rooms | Yes | `HMHome.addRoom(withName:)` |
| Rename rooms | Yes | `HMRoom.updateName` |
| Delete rooms | Yes | `HMHome.removeRoom` |
| List accessories | Yes | `HMHome.accessories` |
| Detect bridged accessories | Yes | `HMAccessory.isBridged`, `bridgedAccessories` |
| Move accessory to room | Yes | `HMHome.assignAccessory(_:to:)` |
| Rename accessory | Yes | `HMAccessory.updateName` |
| Create scenes | Yes | `HMHome.addActionSet(withName:)` |
| Service grouping | Partial | `HMServiceGroup` groups services, not clean whole-accessory UI groups |
| Apple Home UI icon/layout sync | No clear public API | Likely Home app metadata, not HomeKit core |
| Native macOS CLI direct HomeKit | No clean official route | Use Mac Catalyst app instead |

## Platform and entitlement constraints

HomeKit is a protected Apple capability.

A helper app needs:

- HomeKit capability enabled in Xcode.
- Entitlement: `com.apple.developer.homekit`.
- `NSHomeKitUsageDescription` in `Info.plist`.
- User approval when the app first accesses Home data.
- The Apple ID/home role must allow admin-style edits.

Native AppKit macOS command-line tools are not the right target. The practical official Mac route is **Mac Catalyst**.

## Home Assistant HomeKit Bridge relationship

Home Assistant's HomeKit Bridge exposes selected HA entities into Apple Home as bridged HomeKit accessories.

What HA can handle well:

- Selecting which entities are exposed.
- Excluding noisy entities.
- Naming entities before initial pairing via HomeKit Bridge configuration.
- Splitting accessories across multiple bridges when needed.
- Maintaining state/control sync between HA and Apple Home.

What HA does not solve by itself:

- Apple Home room placement.
- Apple Home user-facing organization cleanup after pairing.
- Apple Home service/accessory grouping semantics.
- Retrofitting renamed accessory metadata after Apple Home has cached first-pairing names.

Known HA/HomeKit Bridge caveats:

- HomeKit has accessory-count limits per bridge; HA recommends multiple bridges when needed.
- Apple Home may cache names from first pairing.
- Stable HA `unique_id` / entity IDs matter; changing entity IDs can cause Apple Home to see devices as new.
- Apple Home room assignments live in Apple Home metadata, not in HA's HAP accessory payload.

## Shortcuts, AppleScript, and UI automation

### AppleScript

Home.app is not meaningfully AppleScript-scriptable for room/accessory administration.

### Shortcuts

Shortcuts can control Home accessories/scenes and run automations, but it is not a reliable structural API for:

- Enumerating all HomeKit homes/rooms/accessories.
- Moving accessories between rooms.
- Creating/renaming rooms programmatically.
- Producing a machine-readable diff against Home Assistant.

### Accessibility/UI automation

Possible as a fallback, but brittle:

- Depends on the Home app UI layout.
- Breaks across macOS updates/localization/window state.
- Harder to verify safely.
- Not suitable as the primary design.

## Private frameworks

macOS includes private Home-related frameworks such as:

- `HomeKit.framework`
- `HomeKitCore.framework`
- `HomeDataModel.framework`
- `HomeAppIntents.framework`
- `HomeKitDaemon.framework`
- `HomeKitMatter.framework`

These are not recommended for this project.

Risks:

- Private entitlements may be required.
- APIs can change without notice.
- Not App Store-safe.
- Could corrupt or desynchronize Home data.
- Security/TCC/iCloud permissions may block access anyway.

## Matter is not the answer here

Matter APIs are useful for commissioning/controlling Matter devices and fabrics. They do not provide a public way to edit Apple Home's room/accessory organization metadata.

Matter may matter later for direct device onboarding, but not for Apple Home metadata sync.

## Viability verdict

**Viable with a Mac Catalyst HomeKit helper app.**

Not viable as:

- Pure native macOS CLI using public APIs.
- Pure Home Assistant HomeKit Bridge configuration.
- Shortcuts-only automation.
- Safe private-framework hack.

## Useful source links

- Apple HomeKit framework documentation: https://developer.apple.com/documentation/homekit
- `HMHomeManager`: https://developer.apple.com/documentation/homekit/hmhomemanager
- `HMHome`: https://developer.apple.com/documentation/homekit/hmhome
- `HMAccessory`: https://developer.apple.com/documentation/homekit/hmaccessory
- `HMRoom`: https://developer.apple.com/documentation/homekit/hmroom
- `HMZone`: https://developer.apple.com/documentation/homekit/hmzone
- `HMServiceGroup`: https://developer.apple.com/documentation/homekit/hmservicegroup
- HomeKit entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_homekit
- Home Assistant HomeKit Bridge: https://www.home-assistant.io/integrations/homekit/
- Model Context Protocol: https://modelcontextprotocol.io/
