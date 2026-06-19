import SwiftUI

@main
struct HomeKitMCPHelperApp: App {
    @StateObject private var homeStore = HomeStore()

    var body: some Scene {
        WindowGroup("HomeKit MCP Helper") {
            MenuBarView()
                .environmentObject(homeStore)
                .task {
                    homeStore.start()
                }
        }
    }
}
