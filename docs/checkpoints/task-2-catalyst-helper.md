# Task 2 Checkpoint: Mac Catalyst Helper Proof of Life

## Summary

A minimal HomeKit helper app skeleton exists under `apps/helper-catalyst` and now builds successfully as a Mac Catalyst app when code signing is disabled.

The helper is currently a small native-style Catalyst window, not a true menu bar extra. This is intentional after verification: SwiftUI `MenuBarExtra` is unavailable to this Mac Catalyst target. A future menu bar product shape likely needs either:

1. a small native AppKit menu bar wrapper/launcher that communicates with the Catalyst HomeKit helper, or
2. a different app architecture if HomeKit access can be preserved while using an AppKit shell.

The HomeKit proof-of-life remains valid: the Catalyst target can import HomeKit and compile `HMHomeManager` usage.

## Added

- Native-style SwiftUI Catalyst app entry point.
- Status UI for:
  - HomeKit authorization status.
  - Home count.
  - Selected home.
  - Refresh inventory action.
  - Copy debug summary action.
- `HMHomeManager` proof-of-life store.
- `NSHomeKitUsageDescription` generated through XcodeGen.
- `com.apple.developer.homekit` entitlement file.
- Unit test for inventory debug JSON.
- XcodeGen project spec.
- Generated `HomeKitMCPHelper.xcodeproj`.

## Verification performed

Environment:

```text
macOS 26.2
Xcode 26.5 / build 17F42
```

### Xcode project generation

```bash
cd apps/helper-catalyst
xcodegen generate
```

Result:

```text
Created project at apps/helper-catalyst/HomeKitMCPHelper.xcodeproj
```

### Plist validation

```bash
plutil -p apps/helper-catalyst/HomeKitMCPHelper/Info.plist
```

Confirmed generated plist contains:

```text
NSHomeKitUsageDescription = "This app needs access to Apple Home to inspect rooms and accessories for local metadata synchronization."
```

### Unsigned Mac Catalyst build

```bash
cd apps/helper-catalyst
xcodebuild \
  -project HomeKitMCPHelper.xcodeproj \
  -scheme HomeKitMCPHelper \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result:

```text
** BUILD SUCCEEDED **
```

### Unsigned Mac Catalyst tests

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
Test Suite 'All tests' passed
Executed 1 test, with 0 failures
** TEST SUCCEEDED **
```

### Signed build attempt

```bash
cd apps/helper-catalyst
xcodebuild \
  -project HomeKitMCPHelper.xcodeproj \
  -scheme HomeKitMCPHelper \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  build
```

Result:

```text
Signing for "HomeKitMCPHelper" requires a development team. Select a development team in the Signing & Capabilities editor.
```

## Issues discovered and fixed

### Xcode setup

Initial environment only had Command Line Tools. Full Xcode was installed manually, license accepted, and first-launch packages installed.

### Catalyst API corrections

Fixed compile failures caused by APIs unavailable in Mac Catalyst:

- Replaced `NSPasteboard` with `UIPasteboard`.
- Removed direct `NSApplication.shared.terminate` usage.
- Replaced static `HMHomeManager.authorizationStatus()` usage with instance `manager.authorizationStatus`.
- Avoided deprecated `primaryHome` usage.

### XcodeGen plist generation

XcodeGen overwrote the hand-written `Info.plist`, which removed `NSHomeKitUsageDescription` and caused test launch crashes. The usage description is now declared in `project.yml` so generation is reproducible.

### Deployment target mismatch

Tests initially failed because the generated test target effectively required macOS 26.5 while the Mac runs macOS 26.2. The project now pins `MACOSX_DEPLOYMENT_TARGET` to `14.0` for app and test targets.

## Remaining blocker for real Home permission testing

A signed build requires selecting/configuring a development team for the target.

Until signing is configured, the project can compile and run tests unsigned, but cannot complete the real HomeKit permission prompt/authorization proof.

## Checkpoint decision

This task is ready for review as a **compiled Mac Catalyst HomeKit proof-of-life**.

Next task should proceed only after review approval. The next likely work item is signing/team configuration plus launching the app to request Home access, then moving to the read-only Home inventory inspector.
