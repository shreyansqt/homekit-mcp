import XCTest
@testable import HomeKitMCPMenuBar

final class HelperHTTPClientTests: XCTestCase {
    func testParsesInventorySummaryWithExplicitCounts() throws {
        let json = """
        {
          "generatedAt": "2026-07-17T12:00:00Z",
          "selectedHomeName": "Example Home",
          "homeCount": 2,
          "homes": [
            { "name": "Example Home", "accessoryCount": 3, "accessories": [] },
            { "name": "Other Home", "accessories": [{}, {}] }
          ]
        }
        """

        let summary = try HelperHTTPClient.parseInventorySummary(data: Data(json.utf8))

        XCTAssertEqual(summary.homeCount, 2)
        XCTAssertEqual(summary.accessoryCount, 5)
        XCTAssertEqual(summary.selectedHomeName, "Example Home")
        XCTAssertEqual(summary.generatedAt, "2026-07-17T12:00:00Z")
    }
}
