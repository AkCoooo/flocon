import AppKit

/// Motte de neige arrachée à un tas : elle tourne en tombant, s'écrase au sol puis s'estompe.
/// Chaque motte a son propre calque, pour bouger et pâlir sans redessiner le reste.
final class Clump {
    static let fadeDuration: CGFloat = 0.4

    let layer = CALayer()
    var position: CGPoint
    var velocity: CGVector
    var angle: CGFloat
    let spin: CGFloat
    /// Temps écoulé depuis l'impact, nil tant que la motte tombe.
    var landedFor: CGFloat?

    init(center: CGPoint, size: CGSize, scale: CGFloat) {
        position = center
        velocity = CGVector(dx: .random(in: -40...40), dy: .random(in: -20...40))
        angle = .random(in: -0.2...0.2)
        spin = .random(in: -3...3)

        let bounds = CGRect(origin: .zero, size: size)
        layer.bounds = bounds
        layer.actions = ["position": NSNull(), "transform": NSNull(), "opacity": NSNull()]

        let body = CAShapeLayer()
        body.frame = bounds
        body.contentsScale = scale
        body.path = CGPath(roundedRect: bounds, cornerWidth: size.height / 2, cornerHeight: size.height / 2, transform: nil)
        body.fillColor = NSColor(red: 0.8, green: 0.86, blue: 0.96, alpha: 1).cgColor
        layer.addSublayer(body)

        let top = CAShapeLayer()
        top.frame = bounds
        top.contentsScale = scale
        let highlight = CGRect(x: size.width * 0.06, y: 0, width: size.width * 0.88, height: size.height * 0.7)
        top.path = CGPath(roundedRect: highlight, cornerWidth: highlight.height / 2, cornerHeight: highlight.height / 2,
                          transform: nil)
        top.fillColor = NSColor.white.cgColor
        layer.addSublayer(top)
        apply()
    }

    /// Renvoie false quand la motte a fini de s'estomper et peut disparaître.
    func step(dt: CGFloat, gravity: CGFloat, ground: CGFloat) -> Bool {
        if let elapsed = landedFor {
            landedFor = elapsed + dt
            let progress = min(1, (elapsed + dt) / Self.fadeDuration)
            layer.opacity = Float(1 - progress)
            layer.transform = CATransform3DScale(CATransform3DMakeRotation(angle, 0, 0, 1), 1 + progress * 0.4, 1 - progress * 0.5, 1)
            return progress < 1
        }
        velocity.dy += gravity * dt
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
        angle += spin * dt
        if position.y + layer.bounds.height / 2 >= ground {
            position.y = ground - layer.bounds.height / 2
            landedFor = 0
        }
        apply()
        return true
    }

    private func apply() {
        layer.position = position
        layer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
    }
}
