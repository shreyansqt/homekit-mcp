import Foundation
import HomeKit
import UIKit

@MainActor
final class HomeStore: NSObject, ObservableObject {
    @Published private(set) var authorizationLabel = "Home access: unknown"
    @Published private(set) var authorizationIcon = "questionmark.circle"
    @Published private(set) var homes: [HMHome] = []
    @Published private(set) var selectedHomeName: String?
    @Published private(set) var lastError: String?
    @Published private(set) var serverStatus = "Server: stopped"
    @Published private(set) var serverURL = "http://127.0.0.1:8765"

    private var manager: HMHomeManager?
    private var server: LocalHomeKitServer?

    func start() {
        let manager = HMHomeManager()
        manager.delegate = self
        self.manager = manager
        updateAuthorizationStatus()
        startServer()
    }

    func refresh() {
        updateFromManager()
    }

    func copyDebugSummary() {
        UIPasteboard.general.string = inventoryJSON()
    }

    func inventoryJSON() -> String {
        AppleHomeInventory.from(
            homes: homes,
            authorization: authorizationLabel,
            generatedAt: Date()
        ).jsonText
    }

    private func startServer() {
        guard server == nil else { return }
        do {
            let server = try LocalHomeKitServer(port: 8765) { [weak self] in
                guard let self else { return AppleHomeInventory.empty.jsonText }
                return self.inventoryJSON()
            }
            try server.start()
            self.server = server
            serverStatus = "Server: running on \(serverURL)"
        } catch {
            lastError = "Server failed: \(error.localizedDescription)"
            serverStatus = "Server: failed"
        }
    }

    private func updateFromManager() {
        guard let manager else {
            lastError = "HMHomeManager has not started."
            return
        }

        homes = manager.homes
        selectedHomeName = manager.homes.first?.name
        updateAuthorizationStatus()
    }

    private func updateAuthorizationStatus() {
        guard let manager else {
            authorizationLabel = "Home access: not determined"
            authorizationIcon = "questionmark.circle"
            return
        }

        let status = manager.authorizationStatus
        if status.contains(.authorized) {
            authorizationLabel = "Home access: authorized"
            authorizationIcon = "checkmark.circle.fill"
        } else if status.contains(.restricted) {
            authorizationLabel = "Home access: restricted"
            authorizationIcon = "lock.circle"
        } else if status.contains(.determined) {
            authorizationLabel = "Home access: not authorized"
            authorizationIcon = "xmark.circle"
        } else {
            authorizationLabel = "Home access: not determined"
            authorizationIcon = "questionmark.circle"
        }
    }
}

extension HomeStore: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.updateFromManager()
        }
    }
}
