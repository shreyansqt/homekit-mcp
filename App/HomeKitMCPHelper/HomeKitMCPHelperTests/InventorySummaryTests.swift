import XCTest
@testable import HomeKitMCPHelper

final class InventorySummaryTests: XCTestCase {
    func testDebugTextProducesJSON() throws {
        let summary = InventorySummary(homes: [
            .init(name: "Example Home", roomCount: 2, accessoryCount: 3)
        ])

        let data = try XCTUnwrap(summary.debugText.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let homes = try XCTUnwrap(object?["homes"] as? [[String: Any]])

        XCTAssertEqual(homes.first?["name"] as? String, "Example Home")
        XCTAssertEqual(homes.first?["roomCount"] as? Int, 2)
        XCTAssertEqual(homes.first?["accessoryCount"] as? Int, 3)
    }
}
