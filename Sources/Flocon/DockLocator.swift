import AppKit
import ApplicationServices

/// Demande au Dock où sont ses icônes, via l'API d'Accessibilité.
enum DockLocator {
    private static var cache: CGRect?
    private static var cachedAt: TimeInterval = -1

    static func requestAccess() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Cadre des icônes du Dock en coordonnées globales (origine en haut à gauche), ou nil sans autorisation.
    static func frame() -> CGRect? {
        let now = ProcessInfo.processInfo.systemUptime
        if now - cachedAt < 0.5 { return cache }
        cache = AXIsProcessTrusted() ? fetch() : nil
        cachedAt = now
        return cache
    }

    private static func fetch() -> CGRect? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        guard let list = attribute(app, kAXChildrenAttribute, as: [AXUIElement].self)?
            .first(where: { attribute($0, kAXRoleAttribute, as: String.self) == kAXListRole })
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard
            let position = attribute(list, kAXPositionAttribute, as: AXValue.self),
            let extent = attribute(list, kAXSizeAttribute, as: AXValue.self),
            AXValueGetValue(position, .cgPoint, &origin),
            AXValueGetValue(extent, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// Cadres de la liste et de ses premières icônes, pour le journal de diagnostic.
    static func describe() -> String {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return "dock: pas d'accès" }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        guard let list = attribute(app, kAXChildrenAttribute, as: [AXUIElement].self)?
            .first(where: { attribute($0, kAXRoleAttribute, as: String.self) == kAXListRole })
        else { return "dock: pas de liste" }
        var lines = ["dock list \(frame(of: list).map { "\($0)" } ?? "-")"]
        for item in (attribute(list, kAXChildrenAttribute, as: [AXUIElement].self) ?? []).prefix(4) {
            let title = attribute(item, kAXTitleAttribute, as: String.self) ?? ""
            lines.append("  item '\(title)' \(frame(of: item).map { "\($0)" } ?? "-")")
        }
        return lines.joined(separator: "\n")
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard
            let position = attribute(element, kAXPositionAttribute, as: AXValue.self),
            let extent = attribute(element, kAXSizeAttribute, as: AXValue.self),
            AXValueGetValue(position, .cgPoint, &origin),
            AXValueGetValue(extent, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    static func attribute<T>(_ element: AXUIElement, _ name: String, as _: T.Type) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
