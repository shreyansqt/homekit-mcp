import AppKit
import Foundation

final class LaunchAgentController {
    let label: String
    let plistURL: URL
    let helperAppURL: URL

    init(label: String, plistURL: URL, helperAppURL: URL) {
        self.label = label
        self.plistURL = plistURL
        self.helperAppURL = helperAppURL
    }

    func openHelperWindow() throws {
        guard FileManager.default.fileExists(atPath: helperAppURL.path) else {
            throw HelperControlError.missingHelperApp(helperAppURL.path)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: helperAppURL, configuration: configuration)
    }

    func restart() throws -> String {
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw HelperControlError.missingLaunchAgent(plistURL.path)
        }

        let domain = "gui/\(getuid())"
        var transcript: [String] = []

        terminateRunningHelper()
        transcript.append(try runLaunchctl(arguments: ["bootout", domain, plistURL.path], allowFailure: true))
        transcript.append(try runLaunchctl(arguments: ["bootstrap", domain, plistURL.path], allowFailure: false))
        transcript.append(try runLaunchctl(arguments: ["kickstart", "-k", "\(domain)/\(label)"], allowFailure: true))

        return transcript.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private func terminateRunningHelper() {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: "local.homekitmcp.helper")
            .forEach { $0.terminate() }
    }

    private func runLaunchctl(arguments: [String], allowFailure: Bool) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let command = "launchctl \(arguments.joined(separator: " "))"
        if process.terminationStatus != 0 && !allowFailure {
            throw HelperControlError.launchctlFailed(command: command, output: output)
        }
        if output.isEmpty {
            return "\(command): exit \(process.terminationStatus)"
        }
        return "\(command): exit \(process.terminationStatus)\n\(output)"
    }
}

enum HelperControlError: LocalizedError {
    case missingHelperApp(String)
    case missingLaunchAgent(String)
    case launchctlFailed(command: String, output: String)

    var errorDescription: String? {
        switch self {
        case .missingHelperApp(let path):
            "HomeKitMCPHelper.app was not found at \(path)."
        case .missingLaunchAgent(let path):
            "LaunchAgent plist was not found at \(path)."
        case .launchctlFailed(let command, let output):
            "\(command) failed. \(output)"
        }
    }
}
