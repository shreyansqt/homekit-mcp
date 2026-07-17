import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var homeStore: HomeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statusRows
            Divider()
            actions
        }
        .padding(16)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "house.circle.fill")
                .font(.title2)
            VStack(alignment: .leading) {
                Text("HomeKit MCP Helper")
                    .font(.headline)
                Text("Read-only proof of life")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Spacer()
        }
    }

    private var statusRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(homeStore.authorizationLabel, systemImage: homeStore.authorizationIcon)
            Label(homeStore.serverStatus, systemImage: "network")
            Label(homeStore.serverURL, systemImage: "link")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("Homes: \(homeStore.homes.count)", systemImage: "house.lodge")
            if let selectedHomeName = homeStore.selectedHomeName {
                Label("Selected: \(selectedHomeName)", systemImage: "checkmark.circle")
            } else {
                Label("No home selected", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Refresh Home Inventory") {
                homeStore.refresh()
            }
            .keyboardShortcut("r")

            Button("Copy Debug Summary") {
                homeStore.copyDebugSummary()
            }

            Text("You can close this window; the local server is owned by the app process and keeps running until the app is explicitly quit or stopped by launchd.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
