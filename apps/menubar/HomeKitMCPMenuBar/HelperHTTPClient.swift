import Foundation

final class HelperHTTPClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func snapshot() async -> HelperSnapshot {
        let checkedAt = Date()
        do {
            let health = try await health()
            let inventory = try? await inventorySummary()
            return HelperSnapshot(health: health, inventory: inventory, checkedAt: checkedAt)
        } catch {
            return HelperSnapshot(
                health: HelperHealth(
                    reachable: false,
                    statusText: "offline",
                    detailText: error.localizedDescription
                ),
                inventory: nil,
                checkedAt: checkedAt
            )
        }
    }

    func health() async throws -> HelperHealth {
        let (data, response) = try await session.data(from: baseURL.appendingPathComponent("health"))
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            return HelperHealth(
                reachable: false,
                statusText: "HTTP \(http.statusCode)",
                detailText: String(data: data, encoding: .utf8) ?? "Unexpected health response"
            )
        }

        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let status = object?["status"] as? String ?? "ok"
        return HelperHealth(
            reachable: true,
            statusText: status,
            detailText: String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
        )
    }

    func inventorySummary() async throws -> InventorySummary {
        let (data, response) = try await session.data(from: baseURL.appendingPathComponent("inventory"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try Self.parseInventorySummary(data: data)
    }

    static func parseInventorySummary(data: Data) throws -> InventorySummary {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        let homes = root["homes"] as? [[String: Any]] ?? []
        let explicitHomeCount = root["homeCount"] as? Int
        let accessoryCount = homes.reduce(0) { partial, home in
            if let count = home["accessoryCount"] as? Int {
                return partial + count
            }
            return partial + ((home["accessories"] as? [Any])?.count ?? 0)
        }

        return InventorySummary(
            homeCount: explicitHomeCount ?? homes.count,
            accessoryCount: accessoryCount,
            selectedHomeName: root["selectedHomeName"] as? String,
            generatedAt: root["generatedAt"] as? String
        )
    }
}
