import AppKit

struct TrackedWindow {
    let id: CGWindowID
    /// Coordonnées globales, origine en haut à gauche de l'écran principal.
    let frame: CGRect
}

enum WindowTracker {
    private static var windows: [TrackedWindow] = []
    private static var widgets: [TrackedWindow] = []
    private static var bundleIDs: [pid_t: String] = [:]
    private static let widgetHost = "com.apple.notificationcenterui"

    private static func bundleID(of pid: pid_t) -> String {
        if let known = bundleIDs[pid] { return known }
        let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        bundleIDs[pid] = id
        return id
    }
    private static var cachedAt: TimeInterval = -1

    /// Fenêtres visibles, de la plus en avant à la plus en arrière.
    static func visibleWindows() -> [TrackedWindow] {
        refreshIfNeeded()
        return windows
    }

    /// Widgets posés sur le bureau : derrière les fenêtres, comme les icônes.
    /// Identifiants à partir de 0x8000_0000, comme les icônes, pour ne pas croiser ceux des fenêtres.
    static func desktopWidgets() -> [TrackedWindow] {
        refreshIfNeeded()
        return widgets
    }

    /// Une seule question à macOS par passage, même avec plusieurs écrans.
    private static func refreshIfNeeded() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - cachedAt >= 0.05 else { return }
        cachedAt = now

        // Sans exclure les éléments du bureau, pour voir aussi les widgets.
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let ownPID = ProcessInfo.processInfo.processIdentifier

        windows = []
        widgets = []
        for info in list {
            guard
                let layer = info[kCGWindowLayer as String] as? Int,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            if layer < 0, (60...900).contains(frame.width), (60...900).contains(frame.height),
               let id = info[kCGWindowNumber as String] as? CGWindowID, bundleID(of: pid) == widgetHost {
                // La fenêtre d'un widget déborde de sa carte de 6 points ; 2 de plus en haut pour poser la neige sur la carte.
                let card = CGRect(x: frame.minX + 6, y: frame.minY + 8, width: frame.width - 12, height: frame.height - 14)
                widgets.append(TrackedWindow(id: id | 0x8000_0000, frame: card))
                continue
            }
            guard
                (0...8).contains(layer),
                pid != ownPID,
                let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0,
                let id = info[kCGWindowNumber as String] as? CGWindowID,
                frame.width >= 60, frame.height >= 40
            else { continue }
            windows.append(TrackedWindow(id: id, frame: frame))
        }
    }
}
