import AppKit

/// Petit chasse-neige orange qui traverse le Dock de gauche à droite, gyrophare allumé.
/// La carrosserie est peinte une fois dans une image ; seuls le gyrophare et la fumée sont animés.
final class Snowplow {
    let layer = CALayer()
    private let beacon = CALayer()
    /// Congère poussée par la lame : accrochée au camion, elle roule avec lui à la fréquence de l'écran.
    private let moundBody = CAShapeLayer()
    private let moundTop = CAShapeLayer()
    private var moundHeight: CGFloat = 0
    private let k: CGFloat
    private var lastPuff: TimeInterval = 0

    var size: CGSize { CGSize(width: 56 * k, height: 36 * k) }
    /// Distance du bord gauche du camion à l'avant de sa lame.
    var bladeOffset: CGFloat { 55 * k }

    init(size k: CGFloat, contentsScale: CGFloat) {
        self.k = k
        layer.bounds = CGRect(origin: .zero, size: CGSize(width: 56 * k, height: 36 * k))
        layer.anchorPoint = CGPoint(x: 0, y: 1)
        layer.contentsScale = contentsScale
        layer.contents = Self.draw(k: k, scale: contentsScale)
        layer.actions = ["position": NSNull(), "opacity": NSNull()]

        beacon.bounds = CGRect(x: 0, y: 0, width: 6 * k, height: 4 * k)
        beacon.cornerRadius = 2 * k
        beacon.position = CGPoint(x: 17 * k, y: 3 * k)
        beacon.backgroundColor = NSColor(red: 1, green: 0.62, blue: 0.1, alpha: 1).cgColor
        beacon.shadowColor = NSColor(red: 1, green: 0.55, blue: 0.1, alpha: 1).cgColor
        beacon.shadowOffset = .zero
        beacon.shadowRadius = 5 * k
        beacon.shadowOpacity = 1
        layer.addSublayer(beacon)

        for (mound, color) in [(moundBody, NSColor(red: 0.8, green: 0.86, blue: 0.96, alpha: 1)), (moundTop, .white)] {
            mound.fillColor = color.cgColor
            mound.contentsScale = contentsScale
            mound.actions = ["path": NSNull()]
            layer.addSublayer(mound)
        }

        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [1, 0.25, 1]
        flash.duration = 0.6
        flash.repeatCount = .infinity
        beacon.add(flash, forKey: "flash")

        let rumble = CAKeyframeAnimation(keyPath: "transform.translation.y")
        rumble.values = [0, -0.6 * k, 0, -0.3 * k, 0]
        rumble.duration = 0.3
        rumble.repeatCount = .infinity
        layer.add(rumble, forKey: "rumble")
    }

    /// La congère grossit avec la neige raclée, jusqu'à la hauteur du camion ; au-delà, la neige se tasse.
    func carry(_ area: CGFloat) {
        let height = min(sqrt(area / 0.9), 34 * k)
        guard abs(height - moundHeight) > 0.25 else { return }
        moundHeight = height
        guard height > 1 else {
            moundBody.path = nil
            moundTop.path = nil
            return
        }
        let ground = 36 * k
        let start = bladeOffset - 3 * k
        let width = height * 1.7 + 6 * k
        func heap(top: CGFloat, base: CGFloat) -> CGPath {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: start, y: base))
            path.addLine(to: CGPoint(x: start, y: ground - top * 0.85))
            path.addQuadCurve(to: CGPoint(x: start + width * 0.35, y: ground - top),
                              control: CGPoint(x: start + width * 0.12, y: ground - top * 1.05))
            path.addQuadCurve(to: CGPoint(x: start + width, y: base),
                              control: CGPoint(x: start + width * 0.85, y: ground - top * 0.9))
            path.closeSubpath()
            return path
        }
        moundBody.path = heap(top: height, base: ground)
        moundTop.path = heap(top: height, base: ground - height * 0.35)
    }

    /// Une bouffée de fumée grise derrière le pot d'échappement, quatre fois par seconde.
    func puff(in container: CALayer, at position: CGPoint, now: TimeInterval) {
        guard now - lastPuff > 0.25 else { return }
        lastPuff = now
        let smoke = CALayer()
        let r = CGFloat.random(in: 2.5...4) * k
        smoke.bounds = CGRect(x: 0, y: 0, width: r * 2, height: r * 2)
        smoke.cornerRadius = r
        smoke.backgroundColor = NSColor(white: 0.85, alpha: 0.7).cgColor
        let pipe = CGPoint(x: position.x + 4 * k, y: position.y - 30 * k)
        smoke.position = pipe
        smoke.opacity = 0
        let rise = CABasicAnimation(keyPath: "position")
        rise.fromValue = NSValue(point: pipe)
        rise.toValue = NSValue(point: CGPoint(x: pipe.x - 14 * k, y: pipe.y - 18 * k))
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.5
        grow.toValue = 2
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.8, 0.5, 0]
        let group = CAAnimationGroup()
        group.animations = [rise, grow, fade]
        group.duration = 1.1
        smoke.add(group, forKey: "smoke")
        container.addSublayer(smoke)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { smoke.removeFromSuperlayer() }
    }

    /// Le camion vu de profil, roues au bas de l'image, lame à droite.
    private static func draw(k: CGFloat, scale: CGFloat) -> CGImage? {
        let w = 56 * k, h = 36 * k
        guard let context = CGContext(data: nil, width: Int(ceil(w * scale)), height: Int(ceil(h * scale)),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Origine en haut, comme la vitre.
        context.translateBy(x: 0, y: h * scale)
        context.scaleBy(x: scale, y: -scale)

        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, radius: CGFloat, _ color: NSColor) {
            context.addPath(CGPath(roundedRect: CGRect(x: x * k, y: y * k, width: width * k, height: height * k),
                                   cornerWidth: radius * k, cornerHeight: radius * k, transform: nil))
            context.setFillColor(color.cgColor)
            context.fillPath()
        }
        let orange = NSColor(red: 0.95, green: 0.52, blue: 0.13, alpha: 1)
        let darkOrange = NSColor(red: 0.78, green: 0.36, blue: 0.08, alpha: 1)
        let steel = NSColor(red: 0.62, green: 0.67, blue: 0.76, alpha: 1)
        let tire = NSColor(red: 0.16, green: 0.17, blue: 0.21, alpha: 1)

        rect(3, 8, 2.2, 12, radius: 1, NSColor(white: 0.35, alpha: 1))
        rect(14, 2.5, 7, 3, radius: 1, NSColor(white: 0.3, alpha: 1))
        rect(6, 5, 20, 15, radius: 3, orange)
        rect(9, 7.5, 13, 7, radius: 1.5, NSColor(red: 0.72, green: 0.87, blue: 1, alpha: 1))
        rect(10, 8, 4, 5, radius: 1, NSColor(white: 1, alpha: 0.6))
        rect(4, 17, 40, 11, radius: 3, orange)
        rect(4, 24, 40, 4, radius: 2, darkOrange)
        rect(42, 22, 6, 3, radius: 1, NSColor(white: 0.3, alpha: 1))

        // Lame bombée, plus haute que le capot, éclairée par le haut.
        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: 47 * k, y: 15 * k))
        blade.addQuadCurve(to: CGPoint(x: 47 * k, y: 35 * k), control: CGPoint(x: 52 * k, y: 25 * k))
        blade.addLine(to: CGPoint(x: 55 * k, y: 35 * k))
        blade.addQuadCurve(to: CGPoint(x: 54 * k, y: 15 * k), control: CGPoint(x: 58 * k, y: 25 * k))
        blade.closeSubpath()
        context.saveGState()
        context.addPath(blade)
        context.clip()
        if let shade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [NSColor.white.cgColor, steel.cgColor,
                                           NSColor(red: 0.42, green: 0.47, blue: 0.58, alpha: 1).cgColor] as CFArray,
                                  locations: [0, 0.45, 1]) {
            context.drawLinearGradient(shade, start: CGPoint(x: 0, y: 15 * k), end: CGPoint(x: 0, y: 35 * k), options: [])
        }
        context.restoreGState()

        for x in [14.0, 35.0] {
            context.setFillColor(tire.cgColor)
            context.fillEllipse(in: CGRect(x: (x - 6.5) * k, y: 22.5 * k, width: 13 * k, height: 13 * k))
            context.setFillColor(NSColor(white: 0.7, alpha: 1).cgColor)
            context.fillEllipse(in: CGRect(x: (x - 2.8) * k, y: 26.2 * k, width: 5.6 * k, height: 5.6 * k))
        }
        return context.makeImage()
    }
}
