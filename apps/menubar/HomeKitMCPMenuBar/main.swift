import AppKit

private let app = NSApplication.shared
private let delegate = HomeKitMCPMenuBarApp()

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
