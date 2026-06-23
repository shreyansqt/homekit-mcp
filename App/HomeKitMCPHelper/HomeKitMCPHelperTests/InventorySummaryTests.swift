import XCTest
@testable import HomeKitMCPHelper

final class InventorySummaryTests: XCTestCase {
    func testInventoryDebugTextProducesJSON() throws {
        let summary = AppleHomeInventory(
            generatedAt: "2026-06-19T00:00:00Z",
            authorization: "Home access: authorized",
            selectedHomeName: "Example Home",
            homeCount: 1,
            homes: [
                .init(
                    id: "home-1",
                    name: "Example Home",
                    roomCount: 2,
                    accessoryCount: 3,
                    rooms: [.init(id: "room-1", name: "Living Room")],
                    accessories: []
                )
            ]
        )

        let data = try XCTUnwrap(summary.jsonText.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let homes = try XCTUnwrap(object["homes"] as? [[String: Any]])

        XCTAssertEqual(object["homeCount"] as? Int, 1)
        XCTAssertEqual(homes.first?["name"] as? String, "Example Home")
        XCTAssertEqual(homes.first?["roomCount"] as? Int, 2)
        XCTAssertEqual(homes.first?["accessoryCount"] as? Int, 3)
    }

    func testCharacteristicValueSerialization() throws {
        XCTAssertEqual(AppleHomeInventory.describeValue("ABC123"), "ABC123")
        XCTAssertEqual(AppleHomeInventory.describeValue(true), "true")
        XCTAssertEqual(AppleHomeInventory.describeValue(42), "42")
    }

    func testInventoryEndpointResponse() throws {
        let response = LocalHTTPResponse.response(
            for: "GET /inventory HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n",
            inventoryJSON: "{\"homes\":[]}"
        )
        let text = try XCTUnwrap(String(data: response, encoding: .utf8))

        XCTAssertTrue(text.hasPrefix("HTTP/1.1 200 OK"))
        XCTAssertTrue(text.contains("Content-Type: application/json"))
        XCTAssertTrue(text.contains("{\"homes\":[]}"))
    }

    func testHealthEndpointResponse() throws {
        let response = LocalHTTPResponse.response(
            for: "GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n",
            inventoryJSON: "{}"
        )
        let text = try XCTUnwrap(String(data: response, encoding: .utf8))

        XCTAssertTrue(text.hasPrefix("HTTP/1.1 200 OK"))
        XCTAssertTrue(text.contains("\"status\":\"ok\""))
    }

    func testMCPRequestFiltersHome() throws {
        let summary = AppleHomeInventory(
            generatedAt: "2026-06-19T00:00:00Z",
            authorization: "Home access: authorized",
            selectedHomeName: "Köpenick Home",
            homeCount: 2,
            homes: [
                .init(id: "home-1", name: "My Home", roomCount: 0, accessoryCount: 0, rooms: [], accessories: []),
                .init(id: "home-2", name: "Köpenick Home", roomCount: 9, accessoryCount: 24, rooms: [], accessories: [])
            ]
        )
        let request = "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n{\"tool\":\"homekit_inventory\",\"arguments\":{\"home\":\"Köpenick Home\"}}"
        let response = LocalHTTPResponse.response(for: request, inventoryJSON: summary.jsonText)
        let text = try XCTUnwrap(String(data: response, encoding: .utf8))

        XCTAssertTrue(text.contains("\"homeCount\" : 1"))
        XCTAssertTrue(text.contains("Köpenick Home"))
        XCTAssertFalse(text.contains("My Home"))
    }
}
