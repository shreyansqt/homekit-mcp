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

    private var manager: HMHomeManager?

    func start() {
        let manager = HMHomeManager()
        manager.delegate = self
        self.manager = manager
        updateAuthorizationStatus()
    }

    func refresh() {
        updateFromManager()
    }

    func copyDebugSummary() {
        let summary = InventorySummary.from(homes: homes)
        UIPasteboard.general.string = summary.debugText
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

struct InventorySummary: Codable {
    struct Home: Codable {
        let name: String
        let roomCount: Int
        let accessoryCount: Int
    }

    let homes: [Home]

    static func from(homes: [HMHome]) -> InventorySummary {
        InventorySummary(
            homes: homes.map { home in
                Home(
                    name: home.name,
                    roomCount: home.rooms.count,
                    accessoryCount: home.accessories.count
                )
            }
        )
    }

    var debugText: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }
}
