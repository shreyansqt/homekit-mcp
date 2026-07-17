import Foundation

struct HelperHealth: Equatable {
    let reachable: Bool
    let statusText: String
    let detailText: String

    static let unknown = HelperHealth(
        reachable: false,
        statusText: "Helper status unknown",
        detailText: "Use Refresh to query http://127.0.0.1:8765/health."
    )
}

struct InventorySummary: Equatable {
    let homeCount: Int
    let accessoryCount: Int
    let selectedHomeName: String?
    let generatedAt: String?

    var displayText: String {
        var text = "Inventory: \(homeCount) home\(homeCount == 1 ? "" : "s"), \(accessoryCount) accessor\(accessoryCount == 1 ? "y" : "ies")"
        if let selectedHomeName, !selectedHomeName.isEmpty {
            text += " • selected: \(selectedHomeName)"
        }
        return text
    }
}

struct HelperSnapshot: Equatable {
    let health: HelperHealth
    let inventory: InventorySummary?
    let checkedAt: Date

    var menuStatusText: String {
        health.reachable ? "Helper: \(health.statusText)" : "Helper: offline"
    }
}
