import AppKit

/// Stalactites sous le bord bas d'une fenêtre restée immobile.
/// Chacune est une petite image peinte une fois à sa taille finale : la carte graphique l'affiche,
/// et pousser revient à l'étirer vers le bas, sans rien redessiner.
final class Icicles {
    struct Spike {
        let x: CGFloat
        let width: CGFloat
        let maxLength: CGFloat
        let speed: CGFloat
        var length: CGFloat = 0
    }

    private static let delayBeforeGrowing: TimeInterval = 12

    private(set) var spikes: [Spike]
    private(set) var layers: [CALayer] = []
    private let since = ProcessInfo.processInfo.systemUptime

    init(frame: CGRect, contentsScale: CGFloat) {
        // Serrées et irrégulières : beaucoup de petites, quelques longues.
        var spikes: [Spike] = []
        var x = frame.minX + 24
        while x < frame.maxX - 24 {
            let long = Double.random(in: 0..<1) < 0.3
            spikes.append(Spike(x: x,
                                width: long ? .random(in: 4.5...7) : .random(in: 3...4.5),
                                maxLength: long ? .random(in: 18...36) : .random(in: 6...15),
                                speed: .random(in: 0.8...2)))
            x += .random(in: 9...22)
        }
        self.spikes = spikes
        layers = spikes.map { Self.makeLayer(width: $0.width, length: $0.maxLength, scale: contentsScale) }
    }

    /// Ne pousse que sous la neige : une stalactite naît d'un tas qui fond.
    func grow(seconds: CGFloat, pile: Pile) -> Bool {
        guard ProcessInfo.processInfo.systemUptime - since > Self.delayBeforeGrowing else { return false }
        var changed = false
        for i in spikes.indices where spikes[i].length < spikes[i].maxLength && pile.height(atX: spikes[i].x) > 4 {
            spikes[i].length = min(spikes[i].maxLength, spikes[i].length + spikes[i].speed * seconds)
            changed = true
        }
        return changed
    }

    /// Place chaque stalactite sous le bord, à sa longueur du moment, et cache celles qu'une fenêtre recouvre.
    func layout(bottom: CGFloat, isHidden: (CGFloat) -> Bool) {
        for (spike, layer) in zip(spikes, layers) {
            layer.isHidden = spike.length < 0.5 || isHidden(spike.x)
            guard !layer.isHidden else { continue }
            layer.position = CGPoint(x: spike.x, y: bottom - 0.5)
            layer.transform = CATransform3DMakeScale(1, spike.length / spike.maxLength, 1)
        }
    }

    /// Glace : blanc givré à la base, bleu translucide au milieu, pointe presque transparente ;
    /// une ombre sur le flanc droit, un reflet blanc à gauche du centre et un fin contour bleuté.
    /// Peinte une fois dans une image : des calques masqués coûteraient à macOS un passage hors écran par image.
    private static func makeLayer(width w: CGFloat, length h: CGFloat, scale: CGFloat) -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        layer.actions = ["position": NSNull(), "transform": NSNull(), "hidden": NSNull()]
        layer.isHidden = true
        layer.contentsScale = scale
        layer.contents = draw(width: w, length: h, scale: scale)
        return layer
    }

    private static func draw(width w: CGFloat, length h: CGFloat, scale: CGFloat) -> CGImage? {
        guard let context = CGContext(data: nil, width: Int(ceil(w * scale)), height: Int(ceil(h * scale)),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Origine en haut, comme la vitre : la base de la stalactite est en y = 0.
        context.translateBy(x: 0, y: h * scale)
        context.scaleBy(x: scale, y: -scale)

        let lean = CGFloat.random(in: -1...1)
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: w / 2 + lean, y: h),
                      control1: CGPoint(x: w * 0.12, y: h * 0.3), control2: CGPoint(x: w * 0.42 + lean, y: h * 0.62))
        path.addCurve(to: CGPoint(x: w, y: 0),
                      control1: CGPoint(x: w * 0.58 + lean, y: h * 0.62), control2: CGPoint(x: w * 0.88, y: h * 0.3))
        path.closeSubpath()

        func gradient(_ colors: [NSColor], _ locations: [CGFloat]) -> CGGradient? {
            CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray,
                       locations: locations)
        }

        context.saveGState()
        context.addPath(path)
        context.clip()
        if let body = gradient([NSColor(white: 1, alpha: 0.95),
                                NSColor(red: 0.86, green: 0.93, blue: 1, alpha: 0.78),
                                NSColor(red: 0.7, green: 0.84, blue: 1, alpha: 0.42),
                                NSColor(red: 0.75, green: 0.88, blue: 1, alpha: 0.08)], [0, 0.2, 0.6, 1]) {
            context.drawLinearGradient(body, start: .zero, end: CGPoint(x: 0, y: h), options: [])
        }
        if let side = gradient([NSColor(red: 0.42, green: 0.56, blue: 0.85, alpha: 0),
                                NSColor(red: 0.42, green: 0.56, blue: 0.85, alpha: 0.4)], [0.5, 1]) {
            context.drawLinearGradient(side, start: .zero, end: CGPoint(x: w, y: 0), options: [])
        }
        context.clip(to: CGRect(x: w * 0.3, y: 0, width: max(1, w * 0.16), height: h * 0.8))
        if let shine = gradient([NSColor(white: 1, alpha: 0.95), NSColor(white: 1, alpha: 0)], [0, 1]) {
            context.drawLinearGradient(shine, start: .zero, end: CGPoint(x: 0, y: h * 0.8), options: [])
        }
        context.restoreGState()

        context.addPath(path)
        context.setStrokeColor(NSColor(red: 0.6, green: 0.74, blue: 0.95, alpha: 0.5).cgColor)
        context.setLineWidth(0.6)
        context.strokePath()
        return context.makeImage()
    }
}
