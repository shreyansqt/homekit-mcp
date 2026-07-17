import SwiftUI

@main
struct HomeKitMCPHelperApp: App {
    @StateObject private var homeStore: HomeStore
    @StateObject private var statusBarController: StatusBarController

    init() {
        let store = HomeStore()
        _homeStore = StateObject(wrappedValue: store)
        let statusController = StatusBarController(homeStore: store)
        _statusBarController = StateObject(wrappedValue: statusController)
        Task { @MainActor in
            store.start()
            statusController.install()
        }
    }

    var body: some Scene {
        WindowGroup("HomeKit MCP Helper") {
            MenuBarView()
                .environmentObject(homeStore)
        }
    }
}
