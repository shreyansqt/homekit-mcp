# HomeKit MCP Menu Bar Wrapper

Native macOS AppKit status-item wrapper for the HomeKit MCP Catalyst helper.

The wrapper deliberately does **not** link HomeKit or request HomeKit entitlements. Apple Home access stays in the existing Catalyst helper (`local.homekitmcp.helper`), which serves `http://127.0.0.1:8765`. This app is only a small `LSUIElement` menu-bar controller that talks to the helper over localhost.

## Menu actions

- Shows helper health from `GET /health`.
- Shows inventory summary from `GET /inventory`.
- `Open Helper Window` launches `~/Applications/HomeKitMCPHelper.app` so HomeKit prompts and the Catalyst UI remain normal.
- `Refresh` re-queries localhost immediately; the wrapper also polls every 30 seconds.
- `Restart Helper LaunchAgent` restarts `~/Library/LaunchAgents/local.homekitmcp.helper.plist` with `launchctl bootout/bootstrap/kickstart` and terminates any running helper app instance first.
- `Quit Menu Bar Wrapper` quits only the wrapper; it does not stop the HomeKit helper.

## Build and test

```bash
cd App/HomeKitMCPMenuBar
xcodegen generate
xcodebuild \
  -project HomeKitMCPMenuBar.xcodeproj \
  -scheme HomeKitMCPMenuBar \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild \
  -project HomeKitMCPMenuBar.xcodeproj \
  -scheme HomeKitMCPMenuBar \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The checked-in project contains no personal development team ID. For a signed local install, set your own team in Xcode or pass `DEVELOPMENT_TEAM=YOURTEAMID` to `xcodebuild`.

## Files

- `project.yml` — XcodeGen specification.
- `HomeKitMCPMenuBar.xcodeproj` — generated Xcode project.
- `HomeKitMCPMenuBar/HomeKitMCPMenuBarApp.swift` — app delegate entry point.
- `HomeKitMCPMenuBar/MenuBarController.swift` — `NSStatusItem` and `NSMenu` UI.
- `HomeKitMCPMenuBar/HelperHTTPClient.swift` — `/health` and `/inventory` localhost client.
- `HomeKitMCPMenuBar/LaunchAgentController.swift` — open/restart helper controls.
- `HomeKitMCPMenuBarTests/HelperHTTPClientTests.swift` — inventory summary parsing test.
