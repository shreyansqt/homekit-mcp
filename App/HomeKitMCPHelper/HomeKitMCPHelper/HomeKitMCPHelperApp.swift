import SwiftUI

@main
struct HomeKitMCPHelperApp: App {
    @StateObject private var homeStore: HomeStore

    init() {
        let store = HomeStore()
        _homeStore = StateObject(wrappedValue: store)
        Task { @MainActor in
            store.start()
        }
    }

    var body: some Scene {
        WindowGroup("HomeKit MCP Helper") {
            MenuBarView()
                .environmentObject(homeStore)
        }
    }
}
