import AppKit

final class HomeKitMCPMenuBarApp: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("HomeKit MCP Menu Bar owns a persistent status item")
        let controller = MenuBarController(
            client: HelperHTTPClient(baseURL: URL(string: "http://127.0.0.1:8765")!),
            launchAgent: LaunchAgentController(
                label: "local.homekitmcp.helper",
                plistURL: FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/LaunchAgents/local.homekitmcp.helper.plist"),
                helperAppURL: FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications/HomeKitMCPHelper.app")
            )
        )
        self.controller = controller
        controller.start()
    }
}
