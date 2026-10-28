import AppKit
import ApplicationServices

/// Demande à l'app au premier plan si sa fenêtre est en vrai plein écran (pas seulement agrandie).
enum FullScreenDetector {
    private static var cache = false
    private static var cachedAt: TimeInterval = -1

    static func isFrontAppFullScreen() -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if now - cachedAt < 0.5 { return cache }
        cachedAt = now
        guard AXIsProcessTrusted(), let front = NSWorkspace.shared.frontmostApplication else {
            cache = false
            return cache
        }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        let window = DockLocator.attribute(app, kAXFocusedWindowAttribute, as: AXUIElement.self)
        cache = window.flatMap { DockLocator.attribute($0, "AXFullScreen", as: Bool.self) } ?? false
        return cache
    }
}
