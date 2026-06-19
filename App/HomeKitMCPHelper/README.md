# HomeKit MCP Helper App

Minimal Mac Catalyst proof-of-life skeleton for a native-feeling menu bar helper that requests Apple Home access through HomeKit.

## Current status

The source skeleton and Xcode project are present, but this Mac currently has only Xcode Command Line Tools installed:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

The installed SDKs are also Command-Line-Tools only:

- macOS SDK: available
- iPhoneOS SDK: missing
- iPhoneSimulator SDK: missing

A Mac Catalyst build requires full Xcode, because Catalyst depends on the iOS/iPhoneSimulator SDKs and Xcode project build system.

## Files

- `HomeKitMCPHelper.xcodeproj` — generated Xcode project.
- `project.yml` — XcodeGen spec used to generate the project.
- `HomeKitMCPHelper/HomeKitMCPHelperApp.swift` — menu bar app entry.
- `HomeKitMCPHelper/MenuBarView.swift` — native menu bar status/actions view.
- `HomeKitMCPHelper/HomeStore.swift` — `HMHomeManager` proof-of-life store.
- `HomeKitMCPHelper/Info.plist` — includes `NSHomeKitUsageDescription`.
- `HomeKitMCPHelper/HomeKitMCPHelper.entitlements` — includes `com.apple.developer.homekit`.
- `HomeKitMCPHelperTests/InventorySummaryTests.swift` — first unit test for debug JSON output.

## Build once Xcode is installed

Install full Xcode from the App Store or Apple Developer site, then select it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-path
```

Regenerate the project if needed:

```bash
brew install xcodegen
cd App/HomeKitMCPHelper
xcodegen generate
```

Build:

```bash
cd App/HomeKitMCPHelper
xcodebuild \
  -project HomeKitMCPHelper.xcodeproj \
  -scheme HomeKitMCPHelper \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  build
```

## Expected first-run behavior

1. Launch the app.
2. macOS prompts for Apple Home access.
3. The menu bar app shows authorization status.
4. No Apple Home mutations are performed.

## Notes on Xcode installation attempts

Automated install was attempted but blocked by interactive Apple/App Store requirements:

- `mas install 497799835` required privileged interactive operation.
- `xcodes install 26.2 --directory /Applications --select --no-superuser` required Apple ID credentials.

No credentials should be committed, logged, or handled by this project.
