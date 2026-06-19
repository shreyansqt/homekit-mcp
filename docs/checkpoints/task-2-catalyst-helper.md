# Task 2 Checkpoint: Mac Catalyst Helper Proof of Life

## Summary

A minimal HomeKit helper app skeleton now exists under `App/HomeKitMCPHelper`.

It is designed as a native-feeling Mac menu bar utility using SwiftUI + Mac Catalyst and HomeKit.

## Added

- Menu bar entry point with `MenuBarExtra`.
- Native status UI for:
  - HomeKit authorization status.
  - Home count.
  - Selected home.
  - Refresh inventory action.
  - Copy debug summary action.
- `HMHomeManager` proof-of-life store.
- `NSHomeKitUsageDescription` in `Info.plist`.
- `com.apple.developer.homekit` entitlement file.
- Unit-test skeleton for inventory debug JSON.
- XcodeGen project spec.
- Generated `HomeKitMCPHelper.xcodeproj`.

## Verification performed

### Plist validation

```bash
plutil -lint \
  App/HomeKitMCPHelper/HomeKitMCPHelper/Info.plist \
  App/HomeKitMCPHelper/HomeKitMCPHelper/HomeKitMCPHelper.entitlements
```

Result:

```text
OK
```

### Xcode project generation

```bash
cd App/HomeKitMCPHelper
xcodegen generate
```

Result:

```text
Created project at App/HomeKitMCPHelper/HomeKitMCPHelper.xcodeproj
```

### Build attempt

```bash
cd App/HomeKitMCPHelper
xcodebuild \
  -project HomeKitMCPHelper.xcodeproj \
  -scheme HomeKitMCPHelper \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  build
```

Result:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

## Environment blocker

This Mac currently has only Xcode Command Line Tools selected:

```text
/Library/Developer/CommandLineTools
```

The Mac has the macOS SDK, but not the iPhoneOS/iPhoneSimulator SDKs required for Mac Catalyst builds.

Attempted install routes:

- Installed `mas`, but App Store Xcode install requires privileged interactive operation.
- Installed `xcodes`, but `xcodes install 26.2 --directory /Applications --select --no-superuser` requires Apple ID credentials:

```text
Apple ID: Missing username or a password. Please try again.
```

No Apple ID credentials were handled by the automation agent.

## Next manual step

Install full Xcode, then select it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-path
```

After that, rerun:

```bash
cd App/HomeKitMCPHelper
xcodebuild \
  -project HomeKitMCPHelper.xcodeproj \
  -scheme HomeKitMCPHelper \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  build
```

## Checkpoint decision

This task is ready for review as a **source/project proof-of-life with an environment blocker**.

The implementation should not proceed to Home permission testing until full Xcode is installed and the Catalyst build succeeds.
