import SwiftUI

@main
struct HomeKitMCPHelperApp: App {
    @StateObject private var homeStore = HomeStore()

    var body: some Scene {
        MenuBarExtra("HomeKit MCP Helper", systemImage: "house") {
            MenuBarView()
                .environmentObject(homeStore)
                .task {
                    homeStore.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
