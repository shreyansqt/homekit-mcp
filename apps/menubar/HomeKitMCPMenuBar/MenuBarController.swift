import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let client: HelperHTTPClient
    private let launchAgent: LaunchAgentController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let statusMenuItem = NSMenuItem(title: "Helper: checking…", action: nil, keyEquivalent: "")
    private let inventoryMenuItem = NSMenuItem(title: "Inventory: not loaded", action: nil, keyEquivalent: "")
    private let detailMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastCheckedMenuItem = NSMenuItem(title: "Last checked: never", action: nil, keyEquivalent: "")
    private let refreshMenuItem = NSMenuItem(title: "Refresh", action: #selector(refreshNow), keyEquivalent: "r")
    private let openHelperMenuItem = NSMenuItem(title: "Open Helper Window", action: #selector(openHelperWindow), keyEquivalent: "o")
    private let restartMenuItem = NSMenuItem(title: "Restart Helper LaunchAgent", action: #selector(restartHelper), keyEquivalent: "")
    private let quitMenuItem = NSMenuItem(title: "Quit Menu Bar Wrapper", action: #selector(quit), keyEquivalent: "q")

    private var refreshTask: Task<Void, Never>?

    init(client: HelperHTTPClient, launchAgent: LaunchAgentController) {
        self.client = client
        self.launchAgent = launchAgent
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configureMenu()
    }

    func start() {
        setCheckingState()
        refreshNow()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await self?.refreshNowAsync()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "house.circle", accessibilityDescription: "HomeKit MCP Helper")
        button.imagePosition = .imageLeading
        button.title = "HK"
        statusItem.menu = menu
    }

    private func configureMenu() {
        statusMenuItem.isEnabled = false
        inventoryMenuItem.isEnabled = false
        detailMenuItem.isEnabled = false
        detailMenuItem.attributedTitle = secondaryAttributedTitle("http://127.0.0.1:8765")
        lastCheckedMenuItem.isEnabled = false

        refreshMenuItem.target = self
        openHelperMenuItem.target = self
        restartMenuItem.target = self
        quitMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(inventoryMenuItem)
        menu.addItem(detailMenuItem)
        menu.addItem(lastCheckedMenuItem)
        menu.addItem(.separator())
        menu.addItem(openHelperMenuItem)
        menu.addItem(refreshMenuItem)
        menu.addItem(restartMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)
    }

    private func setCheckingState() {
        statusItem.button?.image = NSImage(systemSymbolName: "house.circle", accessibilityDescription: "Checking")
        statusItem.button?.title = "HK"
        statusMenuItem.title = "Helper: checking…"
        inventoryMenuItem.title = "Inventory: loading…"
        detailMenuItem.attributedTitle = secondaryAttributedTitle("Querying http://127.0.0.1:8765")
    }

    @objc private func refreshNow() {
        Task { await refreshNowAsync() }
    }

    private func refreshNowAsync() async {
        setCheckingState()
        let snapshot = await client.snapshot()
        apply(snapshot: snapshot)
    }

    private func apply(snapshot: HelperSnapshot) {
        statusItem.button?.image = NSImage(
            systemSymbolName: snapshot.health.reachable ? "house.circle.fill" : "house.circle",
            accessibilityDescription: snapshot.health.reachable ? "HomeKit MCP Helper online" : "HomeKit MCP Helper offline"
        )
        statusItem.button?.title = snapshot.health.reachable ? "HK ✓" : "HK !"
        statusMenuItem.title = snapshot.menuStatusText
        if let inventory = snapshot.inventory {
            inventoryMenuItem.title = inventory.displayText
        } else {
            inventoryMenuItem.title = "Inventory: unavailable"
        }
        detailMenuItem.attributedTitle = secondaryAttributedTitle(snapshot.health.detailText)
        lastCheckedMenuItem.title = "Last checked: \(Self.dateFormatter.string(from: snapshot.checkedAt))"
    }

    @objc private func openHelperWindow() {
        do {
            try launchAgent.openHelperWindow()
        } catch {
            present(error: error)
        }
    }

    @objc private func restartHelper() {
        restartMenuItem.isEnabled = false
        statusMenuItem.title = "Helper: restarting…"
        Task {
            do {
                let transcript = try await Task.detached(priority: .userInitiated) { [launchAgent] in
                    try launchAgent.restart()
                }.value
                detailMenuItem.attributedTitle = secondaryAttributedTitle(transcript)
                try? await Task.sleep(for: .seconds(2))
                await refreshNowAsync()
            } catch {
                present(error: error)
            }
            restartMenuItem.isEnabled = true
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func present(error: Error) {
        NSSound.beep()
        statusMenuItem.title = "Helper: action failed"
        detailMenuItem.attributedTitle = secondaryAttributedTitle(error.localizedDescription)
    }

    private func secondaryAttributedTitle(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.menuFont(ofSize: 11)
            ]
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}
