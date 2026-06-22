import Foundation
import HomeKit

struct AppleHomeInventory: Codable {
    struct Home: Codable {
        let id: String
        let name: String
        let roomCount: Int
        let accessoryCount: Int
        let rooms: [Room]
        let accessories: [Accessory]
    }

    struct Room: Codable {
        let id: String
        let name: String
    }

    struct Accessory: Codable {
        let id: String
        let name: String
        let roomName: String?
        let category: String
        let isReachable: Bool
        let isBridged: Bool
        let bridgedAccessoryIds: [String]
        let bridgedAccessoryCount: Int
        let serviceCount: Int
        let services: [Service]
    }

    struct Service: Codable {
        let id: String
        let name: String
        let type: String
        let associatedType: String?
        let characteristicCount: Int
        let characteristics: [Characteristic]
    }

    struct Characteristic: Codable {
        let type: String
        let description: String
        let properties: [String]
    }

    let generatedAt: String
    let authorization: String
    let selectedHomeName: String?
    let homeCount: Int
    let homes: [Home]

    static let empty = AppleHomeInventory(
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        authorization: "Home access: unavailable",
        selectedHomeName: nil,
        homeCount: 0,
        homes: []
    )

    static func from(homes: [HMHome], selectedHomeName: String?, authorization: String, generatedAt: Date) -> AppleHomeInventory {
        AppleHomeInventory(
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            authorization: authorization,
            selectedHomeName: selectedHomeName,
            homeCount: homes.count,
            homes: homes.map { home in
                Home(
                    id: home.uniqueIdentifier.uuidString,
                    name: home.name,
                    roomCount: home.rooms.count,
                    accessoryCount: home.accessories.count,
                    rooms: home.rooms.map { room in
                        Room(id: room.uniqueIdentifier.uuidString, name: room.name)
                    },
                    accessories: home.accessories.map { accessory in
                        Accessory(
                            id: accessory.uniqueIdentifier.uuidString,
                            name: accessory.name,
                            roomName: accessory.room?.name,
                            category: accessory.category.localizedDescription,
                            isReachable: accessory.isReachable,
                            isBridged: accessory.isBridged,
                            bridgedAccessoryIds: accessory.bridgedAccessories.map { $0.uniqueIdentifier.uuidString },
                            bridgedAccessoryCount: accessory.bridgedAccessories.count,
                            serviceCount: accessory.services.count,
                            services: accessory.services.map { service in
                                Service(
                                    id: service.uniqueIdentifier.uuidString,
                                    name: service.name,
                                    type: service.serviceType,
                                    associatedType: service.associatedServiceType,
                                    characteristicCount: service.characteristics.count,
                                    characteristics: service.characteristics.map { characteristic in
                                        Characteristic(
                                            type: characteristic.characteristicType,
                                            description: characteristic.localizedDescription,
                                            properties: characteristic.properties
                                        )
                                    }
                                )
                            }
                        )
                    }
                )
            }
        )
    }

    var jsonText: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    func filtered(homeName: String?) -> AppleHomeInventory {
        guard let homeName, !homeName.isEmpty else { return self }
        let filteredHomes = homes.filter { $0.name.caseInsensitiveCompare(homeName) == .orderedSame }
        return AppleHomeInventory(
            generatedAt: generatedAt,
            authorization: authorization,
            selectedHomeName: filteredHomes.first?.name,
            homeCount: filteredHomes.count,
            homes: filteredHomes
        )
    }
}

// Backward-compatible alias for the first checkpoint's unit test name.
typealias InventorySummary = AppleHomeInventory
