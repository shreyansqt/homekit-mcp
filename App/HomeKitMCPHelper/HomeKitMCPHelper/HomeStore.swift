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
    private var characteristicValues: [UUID: String] = [:]

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
            selectedHomeName: selectedHomeName,
            authorization: authorizationLabel,
            generatedAt: Date(),
            characteristicValues: characteristicValues
        ).jsonText
    }

    private func startServer() {
        guard server == nil else { return }
        do {
            let server = try LocalHomeKitServer(
                port: 8765,
                inventoryProvider: { [weak self] in
                    guard let self else { return AppleHomeInventory.empty.jsonText }
                    return self.inventoryJSON()
                },
                mcpMutationProvider: { [weak self] request in
                    guard let self else { return Self.jsonResponse(error: "home_store_unavailable") }
                    return await self.handleMCPMutation(request)
                }
            )
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
        selectedHomeName = manager.homes.first(where: { !$0.accessories.isEmpty || !$0.rooms.isEmpty })?.name ?? manager.homes.first?.name
        updateAuthorizationStatus()
        refreshCharacteristicValues(for: manager.homes)
    }

    private func handleMCPMutation(_ request: String) async -> String {
        guard MCPRequest.toolName(from: request) == "homekit_move_accessory" else {
            return Self.jsonResponse(error: "unsupported_tool")
        }
        guard let homeName = MCPRequest.homeName(from: request),
              let accessorySerial = MCPRequest.stringArgument("accessory_serial", from: request),
              let targetRoomName = MCPRequest.stringArgument("room", from: request) else {
            return Self.jsonResponse(error: "missing_required_arguments")
        }
        guard let home = homes.first(where: { $0.name.caseInsensitiveCompare(homeName) == .orderedSame }) else {
            return Self.jsonResponse(error: "home_not_found", details: ["home": homeName])
        }
        guard let room = home.rooms.first(where: { $0.name.caseInsensitiveCompare(targetRoomName) == .orderedSame }) else {
            return Self.jsonResponse(error: "room_not_found", details: ["room": targetRoomName])
        }
        guard let accessory = home.accessories.first(where: { serialNumber(for: $0) == accessorySerial }) else {
            return Self.jsonResponse(error: "accessory_not_found", details: ["accessory_serial": accessorySerial])
        }

        let previousRoom = accessory.room?.name
        do {
            try await assign(accessory: accessory, to: room, in: home)
            updateFromManager()
            return Self.jsonResponse(details: [
                "status": "ok",
                "home": home.name,
                "accessory": accessory.name,
                "accessory_serial": accessorySerial,
                "from_room": previousRoom ?? "",
                "to_room": room.name
            ])
        } catch {
            return Self.jsonResponse(error: "move_failed", details: ["message": error.localizedDescription])
        }
    }

    private func serialNumber(for accessory: HMAccessory) -> String? {
        for service in accessory.services {
            for characteristic in service.characteristics where characteristic.localizedDescription == "Serial Number" {
                if let cached = characteristicValues[characteristic.uniqueIdentifier] { return cached }
                if let value = AppleHomeInventory.describeValue(characteristic.value) { return value }
            }
        }
        return nil
    }

    private func assign(accessory: HMAccessory, to room: HMRoom, in home: HMHome) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            home.assignAccessory(accessory, to: room) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func jsonResponse(error: String? = nil, details: [String: String] = [:]) -> String {
        var object = details
        if let error {
            object["status"] = "error"
            object["error"] = error
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{\"status\":\"error\",\"error\":\"json_encoding_failed\"}"
        }
        return text
    }

    private func refreshCharacteristicValues(for homes: [HMHome]) {
        let characteristics = homes
            .flatMap(\.accessories)
            .flatMap(\.services)
            .flatMap(\.characteristics)
            .filter { $0.properties.contains(HMCharacteristicPropertyReadable) }

        for characteristic in characteristics {
            characteristic.readValue { [weak self, weak characteristic] error in
                guard error == nil,
                      let characteristic,
                      let value = AppleHomeInventory.describeValue(characteristic.value) else { return }
                Task { @MainActor in
                    self?.characteristicValues[characteristic.uniqueIdentifier] = value
                }
            }
        }
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
