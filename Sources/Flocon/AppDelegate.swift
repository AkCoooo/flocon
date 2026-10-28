import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var accessItem: NSMenuItem?
    private var snowmanItem: NSMenuItem?
    private var overlays: [NSWindow] = []
    private var snowViews: [SnowView] = []
    private var statusItem: NSStatusItem?
    private var flakesPerSecond: Double = 50
    private var isPaused = false
    private var accumulationBoost: CGFloat = 1
    private var snowmanEnabled = true
    private var snowballsEnabled = true

    private let intensities: [(title: String, flakesPerSecond: Double)] = [
        ("Légère", 50), ("Normale", 150), ("Tempête", 450),
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        createOverlays()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { Self.writeDiagnostics() }
        createMenu()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    /// Ce que macOS répond à Flocon, dans ~/Library/Logs/Flocon.log, pour comprendre ce qui manque.
    private static func writeDiagnostics() {
        let lines = [
            "date=\(Date())",
            "trusted=\(AXIsProcessTrusted())",
            "dock=\(DockLocator.frame().map { "\($0)" } ?? "inconnu")",
            "icones=\(DesktopIcons.frames().count)",
            "widgets=\(WindowTracker.desktopWidgets().count)",
            DockLocator.describe(),
            NSScreen.screens.map { "écran \($0.frame) visible \($0.visibleFrame)" }.joined(separator: "\n"),
            DesktopIcons.dump(),
        ]
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Flocon.log")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    @objc private func screensChanged() {
        snowViews.forEach { $0.stop() }
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
        snowViews.removeAll()
        createOverlays()
    }

    private func createOverlays() {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        for screen in NSScreen.screens {
            createOverlay(on: screen, primaryHeight: primaryHeight)
        }
    }

    /// Une fenêtre transparente au-dessus de tout, que les clics traversent.
    private func createOverlay(on screen: NSScreen, primaryHeight: CGFloat) {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let view = SnowView(frame: CGRect(origin: .zero, size: screen.frame.size))
        window.contentView = view
        window.orderFrontRegardless()

        view.flakesPerSecond = flakesPerSecond
        view.accumulationBoost = accumulationBoost
        view.snowmanEnabled = snowmanEnabled
        view.snowballsEnabled = snowballsEnabled
        view.isPaused = isPaused
        // AppKit compte depuis le bas de l'écran principal, CoreGraphics depuis son haut.
        let screenOrigin = CGPoint(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY)
        view.start(screen: screen, screenOrigin: screenOrigin)
        overlays.append(window)
        snowViews.append(view)
    }

    /// Menu court : l'interrupteur principal, la quantité, le bonhomme, quelques réglages, et Quitter.
    /// Les choix secondaires sont rangés dans des sous-menus.
    private func createMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let symbol = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Flocon")?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        symbol?.isTemplate = true
        item.button?.image = symbol

        let menu = NSMenu()
        menu.addItem(entry("Faire neiger", #selector(togglePause(_:)), key: "p", on: !isPaused))

        let amount = NSMenu()
        for (index, intensity) in intensities.enumerated() {
            let choice = entry(intensity.title, #selector(selectIntensity(_:)), on: intensity.flakesPerSecond == flakesPerSecond)
            choice.tag = index
            amount.addItem(choice)
        }
        menu.addItem(submenu("Quantité", amount))

        let snowman = NSMenu()
        snowman.addItem(entry("Afficher le bonhomme", #selector(toggleSnowman(_:)), on: snowmanEnabled))
        snowman.addItem(entry("Lancer des boules de neige", #selector(toggleSnowballs(_:)), on: snowballsEnabled))
        snowman.addItem(.separator())
        snowman.addItem(entry("En construire un maintenant", #selector(buildSnowmanNow), key: "b"))
        let snowmanItem = submenu("Bonhomme de neige", snowman)
        self.snowmanItem = snowmanItem
        menu.addItem(snowmanItem)

        let settings = NSMenu()
        settings.addItem(entry("Neige qui tient vite", #selector(toggleFastAccumulation(_:)), on: accumulationBoost > 1))
        settings.addItem(entry("Ouvrir au démarrage du Mac", #selector(toggleLaunchAtLogin(_:)),
                               on: SMAppService.mainApp.status == .enabled))
        menu.addItem(submenu("Réglages", settings))

        // Visible seulement tant que macOS n'a pas donné l'accès au Dock et aux icônes.
        let access = entry("Autoriser la neige sur le Dock…", #selector(openAccessibilitySettings))
        accessItem = access
        menu.addItem(access)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter Flocon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    private func entry(_ title: String, _ action: Selector, key: String = "", on: Bool? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let on { item.state = on ? .on : .off }
        return item
    }

    private func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    /// Chaque flocon posé compte six fois : les tas se forment en quelques secondes au lieu de quelques minutes.
    @objc private func toggleFastAccumulation(_ sender: NSMenuItem) {
        accumulationBoost = accumulationBoost == 1 ? 6 : 1
        snowViews.forEach { $0.accumulationBoost = accumulationBoost }
        sender.state = accumulationBoost == 1 ? .off : .on
    }

    @objc private func toggleSnowballs(_ sender: NSMenuItem) {
        snowballsEnabled.toggle()
        snowViews.forEach { $0.snowballsEnabled = snowballsEnabled }
        sender.state = snowballsEnabled ? .on : .off
    }

    @objc private func toggleSnowman(_ sender: NSMenuItem) {
        snowmanEnabled.toggle()
        snowViews.forEach { $0.snowmanEnabled = snowmanEnabled }
        sender.state = snowmanEnabled ? .on : .off
    }

    @objc private func buildSnowmanNow() {
        snowViews.forEach { $0.buildSnowmanNow() }
    }

    func menuWillOpen(_ menu: NSMenu) {
        accessItem?.isHidden = AXIsProcessTrusted()
        // Pas de neige, pas de bonhomme : le sous-menu est grisé tant que la neige est arrêtée.
        snowmanItem?.isEnabled = !isPaused
    }

    @objc private func openAccessibilitySettings() {
        DockLocator.requestAccess()
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let settings = URL(string: url) { NSWorkspace.shared.open(settings) }
    }

    @objc private func selectIntensity(_ sender: NSMenuItem) {
        flakesPerSecond = intensities[sender.tag].flakesPerSecond
        snowViews.forEach { $0.flakesPerSecond = flakesPerSecond }
        sender.menu?.items.forEach { if $0.action == sender.action { $0.state = $0 == sender ? .on : .off } }
    }

    /// macOS garde la liste des apps à ouvrir à la connexion : on s'y inscrit ou on s'en retire.
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        sender.state = service.status == .enabled ? .on : .off
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        isPaused.toggle()
        snowViews.forEach { $0.isPaused = isPaused }
        sender.state = isPaused ? .off : .on
    }
}
