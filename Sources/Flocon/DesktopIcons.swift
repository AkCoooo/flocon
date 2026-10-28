import AppKit
import ApplicationServices

/// Demande au Finder où sont les icônes du bureau, via l'API d'Accessibilité.
enum DesktopIcons {
    private static var cache: [TrackedWindow] = []
    private static var cachedAt: TimeInterval = -1

    /// Icônes en coordonnées globales, avec un identifiant tiré de leur nom.
    /// Les identifiants commencent à 0x8000_0000 pour ne jamais croiser ceux des fenêtres.
    static func frames() -> [TrackedWindow] {
        let now = ProcessInfo.processInfo.systemUptime
        if now - cachedAt < 0.5 { return cache }
        cache = AXIsProcessTrusted() ? fetch() : []
        cachedAt = now
        return cache
    }

    private static func fetch() -> [TrackedWindow] {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        else { return [] }
        let app = AXUIElementCreateApplication(finder.processIdentifier)
        guard let desktop = children(of: app).first(where: { role(of: $0) == kAXScrollAreaRole }) else { return [] }

        var icons: [TrackedWindow] = []
        for group in children(of: desktop) {
            for icon in children(of: group) {
                guard let frame = frame(of: icon), frame.width < 300, frame.height < 300 else { continue }
                let name = DockLocator.attribute(icon, kAXTitleAttribute, as: String.self) ?? "\(frame)"
                let id = CGWindowID(0x8000_0000) | CGWindowID(truncatingIfNeeded: name.hashValue & 0x7FFF_FFFF)
                icons.append(TrackedWindow(id: id, frame: imageArea(of: frame)))
            }
        }
        return icons
    }

    /// Arbre d'Accessibilité du Finder, pour comprendre où il range ses icônes.
    static func dump() -> String {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        else { return "Finder introuvable" }
        var lines = ["trusted=\(AXIsProcessTrusted())"]
        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 6 else { return }
            let title = DockLocator.attribute(element, kAXTitleAttribute, as: String.self) ?? ""
            let description = DockLocator.attribute(element, kAXDescriptionAttribute, as: String.self) ?? ""
            let indent = String(repeating: "  ", count: depth)
            lines.append("\(indent)\(role(of: element) ?? "?") '\(title)' '\(description)' \(frame(of: element).map { "\($0)" } ?? "-")")
            for child in children(of: element).prefix(15) { walk(child, depth: depth + 1) }
        }
        walk(AXUIElementCreateApplication(finder.processIdentifier), depth: 0)
        return lines.joined(separator: "\n")
    }

    /// Le Finder donne le carré de l'icône ; le dessin d'un dossier commence plus bas et moins large.
    private static func imageArea(of cell: CGRect) -> CGRect {
        CGRect(x: cell.minX + cell.width * 0.06, y: cell.minY + cell.height * 0.16,
               width: cell.width * 0.88, height: cell.height * 0.84)
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        DockLocator.attribute(element, kAXChildrenAttribute, as: [AXUIElement].self) ?? []
    }

    private static func role(of element: AXUIElement) -> String? {
        DockLocator.attribute(element, kAXRoleAttribute, as: String.self)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard
            let position = DockLocator.attribute(element, kAXPositionAttribute, as: AXValue.self),
            let extent = DockLocator.attribute(element, kAXSizeAttribute, as: AXValue.self),
            AXValueGetValue(position, .cgPoint, &origin),
            AXValueGetValue(extent, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
