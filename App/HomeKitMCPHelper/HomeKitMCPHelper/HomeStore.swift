import Foundation
import HomeKit
#if canImport(AppKit)
import AppKit
#endif

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
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary.debugText, forType: .string)
        #endif
    }

    private func updateFromManager() {
        guard let manager else {
            lastError = "HMHomeManager has not started."
            return
        }

        homes = manager.homes
        selectedHomeName = manager.primaryHome?.name ?? manager.homes.first?.name
        updateAuthorizationStatus()
    }

    private func updateAuthorizationStatus() {
        if #available(iOS 13.0, macCatalyst 13.0, *) {
            let status = HMHomeManager.authorizationStatus()
            switch status {
            case []:
                authorizationLabel = "Home access: not determined"
                authorizationIcon = "questionmark.circle"
            case .authorized:
                authorizationLabel = "Home access: authorized"
                authorizationIcon = "checkmark.circle.fill"
            case .restricted:
                authorizationLabel = "Home access: restricted"
                authorizationIcon = "lock.circle"
            case .determined:
                authorizationLabel = "Home access: determined"
                authorizationIcon = "checkmark.circle"
            default:
                authorizationLabel = "Home access: \(status.rawValue)"
                authorizationIcon = "questionmark.circle"
            }
        } else {
            authorizationLabel = "Home access: unavailable on this OS"
            authorizationIcon = "xmark.circle"
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
