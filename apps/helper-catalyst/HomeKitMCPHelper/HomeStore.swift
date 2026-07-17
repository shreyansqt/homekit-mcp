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
        if tool == "homekit_create_scene" {
            return await handleCreateScene(request)
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


    private func handleCreateScene(_ request: String) async -> String {
        guard let homeName = MCPRequest.homeName(from: request),
              let sceneName = MCPRequest.stringArgument("name", from: request) else {
            return Self.jsonResponse(error: "missing_required_arguments")
        }
        guard let home = homes.first(where: { $0.name.caseInsensitiveCompare(homeName) == .orderedSame }) else {
            return Self.jsonResponse(error: "home_not_found", details: ["home": homeName])
        }
        let mode = MCPRequest.mutationMode(from: request)
        let sceneActions = MCPRequest.sceneActions(from: request)
        guard !sceneActions.isEmpty else {
            return Self.jsonResponse(error: "missing_scene_actions", details: ["scene": sceneName])
        }
        let planned = plannedActionDescriptions(sceneActions, in: home)
        guard mode == "apply" else {
            return Self.jsonResponse(object: [
                "status": mode == "dry_run" ? "dry_run" : "planned",
                "tool": "homekit_create_scene",
                "mode": mode,
                "home": home.name,
                "scene": sceneName,
                "action_count": planned.count,
                "actions": planned
            ])
        }
        guard MCPRequest.boolArgument("confirm_apply", from: request) else {
            return Self.jsonResponse(error: "apply_requires_confirm_apply")
        }
        do {
            if let existing = home.actionSets.first(where: { $0.name.caseInsensitiveCompare(sceneName) == .orderedSame }) {
                try await remove(actionSet: existing, from: home)
            }
            let actionSet = try await addActionSet(named: sceneName, to: home)
            var added = 0
            for sceneAction in sceneActions {
                guard let accessory = findAccessory(in: home, identifier: sceneAction.entityId) else { continue }
                let writeActions = makeWriteActions(for: sceneAction, accessory: accessory)
                for writeAction in writeActions {
                    try await add(action: writeAction, to: actionSet)
                    added += 1
                }
            }
            updateFromManager()
            return Self.jsonResponse(object: [
                "status": "ok",
                "home": home.name,
                "scene": sceneName,
                "action_count": added
            ])
        } catch {
            return Self.jsonResponse(error: "scene_create_failed", details: ["message": error.localizedDescription])
        }
    }

    private func plannedActionDescriptions(_ sceneActions: [SceneAction], in home: HMHome) -> [[String: String]] {
        sceneActions.map { sceneAction in
            let found = findAccessory(in: home, identifier: sceneAction.entityId) != nil ? "true" : "false"
            return [
                "entity_id": sceneAction.entityId,
                "state": sceneAction.state,
                "found": found,
                "brightness": sceneAction.brightness.map(String.init) ?? "",
                "xy_color": sceneAction.xyColor.map { "\($0[0]),\($0[1])" } ?? "",
                "target_position": sceneAction.targetPosition.map(String.init) ?? ""
            ]
        }
    }

    private func makeWriteActions(for sceneAction: SceneAction, accessory: HMAccessory) -> [HMCharacteristicWriteAction<NSCopying>] {
        var result: [HMCharacteristicWriteAction<NSCopying>] = []
        func writable(_ description: String) -> HMCharacteristic? {
            accessory.services
                .flatMap(\.characteristics)
                .first { $0.localizedDescription == description && $0.properties.contains(HMCharacteristicPropertyWritable) }
        }
        func append(_ description: String, value: NSCopying) {
            if let characteristic = writable(description) {
                result.append(HMCharacteristicWriteAction(characteristic: characteristic, targetValue: value))
            }
        }
        switch sceneAction.entityId.split(separator: ".").first.map(String.init) {
        case "cover":
            if sceneAction.state == "open" { append("Target Position", value: NSNumber(value: 100)) }
            else if sceneAction.state == "closed" { append("Target Position", value: NSNumber(value: 0)) }
            else if let target = sceneAction.targetPosition { append("Target Position", value: NSNumber(value: target)) }
        default:
            append("Power State", value: NSNumber(value: sceneAction.state == "on"))
            guard sceneAction.state == "on" else { return result }
            if let brightness = sceneAction.brightness {
                append("Brightness", value: NSNumber(value: max(1, min(100, Int(round(Double(brightness) * 100.0 / 255.0))))))
            }
            if let xy = sceneAction.xyColor, xy.count == 2 {
                let hs = Self.hueSaturationFromXY(x: xy[0], y: xy[1])
                append("Hue", value: NSNumber(value: hs.hue))
                append("Saturation", value: NSNumber(value: hs.saturation))
            }
            if let colorTemperature = sceneAction.colorTemperature {
                append("Color Temperature", value: NSNumber(value: colorTemperature))
            }
        }
        return result
    }

    private static func hueSaturationFromXY(x: Double, y: Double) -> (hue: Double, saturation: Double) {
        guard y > 0 else { return (0, 0) }
        let Y = 1.0
        let X = (Y / y) * x
        let Z = (Y / y) * (1.0 - x - y)
        var r = X * 1.656492 - Y * 0.354851 - Z * 0.255038
        var g = -X * 0.707196 + Y * 1.655397 + Z * 0.036152
        var b = X * 0.051713 - Y * 0.121364 + Z * 1.011530
        func gamma(_ c: Double) -> Double { c <= 0.0031308 ? 12.92 * c : (1.0 + 0.055) * pow(c, 1.0 / 2.4) - 0.055 }
        r = max(0, gamma(r)); g = max(0, gamma(g)); b = max(0, gamma(b))
        let maxv = max(r, g, b), minv = min(r, g, b)
        let delta = maxv - minv
        var hue = 0.0
        if delta != 0 {
            if maxv == r { hue = 60.0 * ((g - b) / delta).truncatingRemainder(dividingBy: 6.0) }
            else if maxv == g { hue = 60.0 * (((b - r) / delta) + 2.0) }
            else { hue = 60.0 * (((r - g) / delta) + 4.0) }
        }
        if hue < 0 { hue += 360.0 }
        let saturation = maxv == 0 ? 0 : (delta / maxv) * 100.0
        return (hue, saturation)
    }

    private func addActionSet(named name: String, to home: HMHome) async throws -> HMActionSet {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HMActionSet, Error>) in
            home.addActionSet(withName: name) { actionSet, error in
                if let error { continuation.resume(throwing: error) }
                else if let actionSet { continuation.resume(returning: actionSet) }
                else { continuation.resume(throwing: NSError(domain: "HomeKitMCPHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Action set creation returned nil"])) }
            }
        }
    }

    private func remove(actionSet: HMActionSet, from home: HMHome) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            home.removeActionSet(actionSet) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func add(action: HMCharacteristicWriteAction<NSCopying>, to actionSet: HMActionSet) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            actionSet.addAction(action) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
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
        var object: [String: Any] = details
        if let error {
            object["status"] = "error"
            object["error"] = error
        }
        return jsonResponse(object: object)
    }

    private static func jsonResponse(object: [String: Any]) -> String {
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

struct SceneAction {
    let entityId: String
    let state: String
    let brightness: Int?
    let xyColor: [Double]?
    let colorTemperature: Int?
    let targetPosition: Int?
}

extension HomeStore: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.updateFromManager()
        }
    }
}
