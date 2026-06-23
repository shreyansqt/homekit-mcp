import Foundation
import Network

@MainActor
final class LocalHomeKitServer {
    private let port: UInt16
    private let inventoryProvider: @MainActor () -> String
    private let mcpMutationProvider: (@MainActor (String) async -> String)?
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    init(
        port: UInt16,
        inventoryProvider: @escaping @MainActor () -> String,
        mcpMutationProvider: (@MainActor (String) async -> String)? = nil
    ) throws {
        self.port = port
        self.inventoryProvider = inventoryProvider
        self.mcpMutationProvider = mcpMutationProvider
        self.listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() throws {
        guard let listener else { throw ServerError.notConfigured }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.accept(connection)
            }
        }
        listener.start(queue: .main)
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: .main)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            Task { @MainActor in
                guard let self else { return }
                let request = String(data: data ?? Data(), encoding: .utf8) ?? ""
                let inventory = self.inventoryProvider()
                let response: Data
                if MCPRequest.isMoveAccessoryRequest(request), let mcpMutationProvider = self.mcpMutationProvider {
                    let body = await mcpMutationProvider(request)
                    response = LocalHTTPResponse.http(status: "200 OK", body: body + "\n")
                } else {
                    response = LocalHTTPResponse.response(for: request, inventoryJSON: inventory)
                }
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    enum ServerError: Error {
        case notConfigured
    }
}

enum LocalHTTPResponse {
    static func response(for request: String, inventoryJSON: String) -> Data {
        let firstLine = request.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""

        if firstLine.hasPrefix("GET /health ") {
            return http(status: "200 OK", body: "{\"status\":\"ok\"}\n")
        }

        if firstLine.hasPrefix("GET /inventory ") {
            return http(status: "200 OK", body: inventoryJSON + "\n")
        }

        if firstLine.hasPrefix("POST /mcp ") {
            let homeName = MCPRequest.homeName(from: request)
            let body = MCPRequest.filteredInventory(inventoryJSON: inventoryJSON, homeName: homeName)
            return http(status: "200 OK", body: body + "\n")
        }

        if firstLine.hasPrefix("GET / ") {
            let body = """
            {"name":"HomeKit MCP Helper","tools":["homekit_inventory"],"endpoints":{"health":"/health","inventory":"/inventory","mcp":"/mcp"}}
            """
            return http(status: "200 OK", body: body + "\n")
        }

        return http(status: "404 Not Found", body: "{\"error\":\"not_found\"}\n")
    }

    static func http(status: String, body: String) -> Data {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: http://127.0.0.1\r
        \r

        """
        var data = Data(header.utf8)
        data.append(bodyData)
        return data
    }
}

enum MCPRequest {
    static func isMoveAccessoryRequest(_ request: String) -> Bool {
        toolName(from: request) == "homekit_move_accessory"
    }

    static func toolName(from request: String) -> String? {
        object(from: request)?["tool"] as? String
    }

    static func homeName(from request: String) -> String? {
        guard let object = object(from: request) else { return nil }

        if let home = object["home"] as? String { return home }
        if let arguments = object["arguments"] as? [String: Any],
           let home = arguments["home"] as? String {
            return home
        }

        return nil
    }

    static func stringArgument(_ name: String, from request: String) -> String? {
        guard let object = object(from: request) else { return nil }
        if let value = object[name] as? String { return value }
        if let arguments = object["arguments"] as? [String: Any],
           let value = arguments[name] as? String {
            return value
        }
        return nil
    }

    private static func object(from request: String) -> [String: Any]? {
        guard let body = request.components(separatedBy: "\r\n\r\n").last,
              let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    static func filteredInventory(inventoryJSON: String, homeName: String?) -> String {
        guard let data = inventoryJSON.data(using: .utf8),
              let inventory = try? JSONDecoder().decode(AppleHomeInventory.self, from: data) else {
            return inventoryJSON
        }

        return inventory.filtered(homeName: homeName).jsonText
    }
}
