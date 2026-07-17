import Foundation

@MainActor
final class StatusBarController: ObservableObject {
    init(homeStore: HomeStore) {}

    func install() {
        // AppKit status item APIs (NSStatusBar/NSStatusItem/NSMenu) and
        // SwiftUI MenuBarExtra are unavailable to Catalyst targets. Keep this
        // seam so a future native AppKit wrapper can own the real menu bar
        // extra while this HomeKit-entitled Catalyst helper continues serving
        // localhost. Do not hide the Catalyst app with LSUIElement: HomeKit
        // privacy prompts need a normal app presentation.
    }
}
