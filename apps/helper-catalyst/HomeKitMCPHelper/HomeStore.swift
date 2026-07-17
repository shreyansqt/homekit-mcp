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
        guard manager == nil else {
            startServer()
            return
        }
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
        guard let tool = MCPRequest.toolName(from: request) else {
            return Self.jsonResponse(error: "unsupported_tool")
        }

        if tool == "homekit_remove_accessory" {
            return await handleRemoveAccessory(request)
        }

        guard tool == "homekit_move_accessory" else {
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
        guard let accessory = findAccessory(in: home, identifier: accessorySerial) else {
            return Self.jsonResponse(error: "accessory_not_found", details: ["accessory_serial": accessorySerial])
        }

        let mode = MCPRequest.mutationMode(from: request)
        guard mode == "apply" else {
            return Self.jsonResponse(details: [
                "status": mode == "dry_run" ? "dry_run" : "planned",
                "tool": "homekit_move_accessory",
                "mode": mode,
                "home": home.name,
                "accessory": accessory.name,
                "accessory_serial": accessorySerial,
                "from_room": accessory.room?.name ?? "",
                "to_room": room.name
            ])
        }
        guard MCPRequest.boolArgument("confirm_apply", from: request) else {
            return Self.jsonResponse(error: "apply_requires_confirm_apply")
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

    private func handleRemoveAccessory(_ request: String) async -> String {
        guard let homeName = MCPRequest.homeName(from: request),
              let accessoryIdentifier = MCPRequest.stringArgument("accessory", from: request)
                ?? MCPRequest.stringArgument("accessory_name", from: request)
                ?? MCPRequest.stringArgument("accessory_serial", from: request)
                ?? MCPRequest.stringArgument("accessory_id", from: request) else {
            return Self.jsonResponse(error: "missing_required_arguments")
        }
        guard let home = homes.first(where: { $0.name.caseInsensitiveCompare(homeName) == .orderedSame }) else {
            return Self.jsonResponse(error: "home_not_found", details: ["home": homeName])
        }
        guard let accessory = findAccessory(in: home, identifier: accessoryIdentifier) else {
            return Self.jsonResponse(error: "accessory_not_found", details: ["accessory": accessoryIdentifier])
        }

        let mode = MCPRequest.mutationMode(from: request)
        guard mode == "apply" else {
            return Self.jsonResponse(details: [
                "status": mode == "dry_run" ? "dry_run" : "planned",
                "tool": "homekit_remove_accessory",
                "mode": mode,
                "home": home.name,
                "accessory": accessory.name,
                "requested_accessory": accessoryIdentifier,
                "from_room": accessory.room?.name ?? ""
            ])
        }
        guard MCPRequest.boolArgument("confirm_apply", from: request) else {
            return Self.jsonResponse(error: "apply_requires_confirm_apply")
        }

        do {
            let removedName = accessory.name
            try await remove(accessory: accessory, from: home)
            updateFromManager()
            return Self.jsonResponse(details: [
                "status": "ok",
                "home": home.name,
                "removed_accessory": removedName,
                "requested_accessory": accessoryIdentifier
            ])
        } catch {
            return Self.jsonResponse(error: "remove_failed", details: ["message": error.localizedDescription])
        }
    }

    private func findAccessory(in home: HMHome, identifier: String) -> HMAccessory? {
        home.accessories.first { accessory in
            accessory.uniqueIdentifier.uuidString.caseInsensitiveCompare(identifier) == .orderedSame
                || accessory.name.caseInsensitiveCompare(identifier) == .orderedSame
                || serialNumber(for: accessory)?.caseInsensitiveCompare(identifier) == .orderedSame
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

    private func remove(accessory: HMAccessory, from home: HMHome) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            home.removeAccessory(accessory) { error in
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
