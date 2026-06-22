import Foundation
import Network

@MainActor
final class LocalHomeKitServer {
    private let port: UInt16
    private let inventoryProvider: @MainActor () -> String
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    init(port: UInt16, inventoryProvider: @escaping @MainActor () -> String) throws {
        self.port = port
        self.inventoryProvider = inventoryProvider
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
                let response = LocalHTTPResponse.response(for: request, inventoryJSON: inventory)
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

        if firstLine.hasPrefix("GET /inventory ") || firstLine.hasPrefix("POST /mcp ") {
            return http(status: "200 OK", body: inventoryJSON + "\n")
        }

        if firstLine.hasPrefix("GET / ") {
            let body = """
            {"name":"HomeKit MCP Helper","tools":["homekit_inventory"],"endpoints":{"health":"/health","inventory":"/inventory","mcp":"/mcp"}}
            """
            return http(status: "200 OK", body: body + "\n")
        }

        return http(status: "404 Not Found", body: "{\"error\":\"not_found\"}\n")
    }

    private static func http(status: String, body: String) -> Data {
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
