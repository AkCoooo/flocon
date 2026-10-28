import AppKit

/// Petites images symétriques dessinées une seule fois au démarrage, puis réutilisées par la carte graphique.
enum Sprites {
    /// Point de neige flou, pour les flocons du fond.
    static let softDot: CGImage? = draw(size: 16) { context in
        let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.3, 1])
        else { return }
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: 8, y: 8), startRadius: 0,
                                   endCenter: CGPoint(x: 8, y: 8), endRadius: 8, options: [])
    }

    /// Cristal à six branches, pour les gros flocons du décor.
    static let crystal: CGImage? = draw(size: 64) { context in
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(3)
        context.setLineCap(.round)
        let c = CGPoint(x: 32, y: 32)
        for arm in 0..<6 {
            let a = CGFloat(arm) * .pi / 3
            context.move(to: c)
            context.addLine(to: CGPoint(x: c.x + cos(a) * 28, y: c.y + sin(a) * 28))
            let joint = CGPoint(x: c.x + cos(a) * 16, y: c.y + sin(a) * 16)
            for side in [-1.0, 1.0] {
                let b = a + CGFloat(side) * 0.7
                context.move(to: joint)
                context.addLine(to: CGPoint(x: joint.x + cos(b) * 9, y: joint.y + sin(b) * 9))
            }
        }
        context.strokePath()
    }

    private static func draw(size: Int, _ body: (CGContext) -> Void) -> CGImage? {
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        body(context)
        return context.makeImage()
    }
}
