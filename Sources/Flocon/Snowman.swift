import AppKit

/// Bonhomme de neige posé sur le Dock : il se construit en roulant ses boules, vit un moment
/// (respire, cligne des yeux, regarde autour, se gratte la tête, salue), puis fond.
/// Toutes les parties sont des calques animés par Core Animation : le processeur ne calcule rien image par image.
/// Repère : origine au pied du bonhomme, y vers le bas (vers le haut = y négatif).
final class Snowman {
    let layer = CALayer()
    private let body = CALayer()
    private let head = CALayer()
    private let eyes = CALayer()
    private let leftArm = CAShapeLayer()
    private let rightArm = CAShapeLayer()
    private let nose = CAShapeLayer()
    private let scarf = CALayer()
    private let scarfTail = CALayer()
    private var mouth: [CALayer] = []
    private var buttons: [CALayer] = []
    /// Boules dans l'ordre : bas, milieu, tête. Chacune porte une texture qui tourne quand elle roule.
    private var balls: [CALayer] = []
    private var textures: [CALayer] = []

    private let k: CGFloat
    private let scale: CGFloat
    private let r1: CGFloat, r2: CGFloat, r3: CGFloat
    private let c1: CGFloat, c2: CGFloat, c3: CGFloat

    init(at foot: CGPoint, size k: CGFloat, contentsScale: CGFloat) {
        self.k = k
        scale = contentsScale
        r1 = 46 * k; r2 = 34 * k; r3 = 25 * k
        c1 = -r1 + 4 * k
        c2 = c1 - (r1 + r2) * 0.78
        c3 = c2 - (r2 + r3) * 0.8

        // Calques à taille nulle : leurs enfants se placent directement dans le repère du pied.
        for container in [layer, body, head, eyes, scarf] { container.bounds = .zero }
        layer.position = foot
        layer.addSublayer(body)

        body.addSublayer(crease(width: r1 * 2.3, at: CGPoint(x: 0, y: 0)))
        body.addSublayer(ball(radius: r1, center: CGPoint(x: 0, y: c1)))
        body.addSublayer(crease(width: r2 * 1.9, at: CGPoint(x: 0, y: c2 + r2 - 2 * k)))
        body.addSublayer(ball(radius: r2, center: CGPoint(x: 0, y: c2)))
        buttons = [-12, 0, 12].map { dy in dot(radius: 2.6 * k, at: CGPoint(x: 2 * k, y: c2 + dy * k)) }
        buttons.forEach(body.addSublayer)

        head.position = CGPoint(x: 0, y: c3)
        head.addSublayer(crease(width: r3 * 1.8, at: CGPoint(x: 0, y: r3 - 2 * k)))
        head.addSublayer(ball(radius: r3, center: .zero))
        eyes.position = CGPoint(x: -1.5 * k, y: -7 * k)
        eyes.addSublayer(dot(radius: 2.8 * k, at: CGPoint(x: -7.5 * k, y: 0)))
        eyes.addSublayer(dot(radius: 2.8 * k, at: CGPoint(x: 7.5 * k, y: 0)))
        head.addSublayer(eyes)
        for i in 0..<5 {
            let a = CGFloat.pi * (0.2 + 0.15 * CGFloat(i))
            mouth.append(dot(radius: 1.5 * k, at: CGPoint(x: -1.5 * k + cos(a) * 11 * k, y: 3 * k + sin(a) * 7 * k)))
        }
        mouth.forEach(head.addSublayer)
        makeNose()
        head.addSublayer(nose)
        body.addSublayer(head)

        makeScarf()
        body.addSublayer(scarf)
        makeArm(leftArm, side: -1)
        makeArm(rightArm, side: 1)
        body.addSublayer(leftArm)
        body.addSublayer(rightArm)
    }

    // MARK: - Dessin des parties

    /// Boule de neige en volume : ombrage de sphère, grain de neige bosselé qui tourne quand elle roule,
    /// reflet en haut à gauche et bord assombri.
    private func ball(radius: CGFloat, center: CGPoint) -> CALayer {
        let g = CAGradientLayer()
        g.type = .radial
        g.colors = [NSColor.white.cgColor,
                    NSColor(red: 0.93, green: 0.95, blue: 1, alpha: 1).cgColor,
                    NSColor(red: 0.8, green: 0.85, blue: 0.95, alpha: 1).cgColor,
                    NSColor(red: 0.6, green: 0.68, blue: 0.85, alpha: 1).cgColor]
        g.locations = [0, 0.35, 0.75, 1]
        g.startPoint = CGPoint(x: 0.36, y: 0.3)
        g.endPoint = CGPoint(x: 1.2, y: 1.2)
        g.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        // Accrochée par le bas : elle se pose et s'écrase sur le sol, et s'affaisse en fondant.
        g.anchorPoint = CGPoint(x: 0.5, y: 1)
        g.position = CGPoint(x: center.x, y: center.y + radius)
        g.cornerRadius = radius
        g.masksToBounds = true
        g.contentsScale = scale

        let grain = CALayer()
        grain.bounds = g.bounds
        grain.position = CGPoint(x: radius, y: radius)
        grain.contents = Self.snowGrain(diameter: radius * 2 * scale)
        grain.contentsGravity = .resize
        g.addSublayer(grain)

        let shine = CAGradientLayer()
        shine.type = .radial
        shine.colors = [NSColor(white: 1, alpha: 0.85).cgColor, NSColor(white: 1, alpha: 0).cgColor]
        shine.startPoint = CGPoint(x: 0.5, y: 0.5)
        shine.endPoint = CGPoint(x: 1, y: 1)
        shine.frame = CGRect(x: radius * 0.25, y: radius * 0.2, width: radius * 0.8, height: radius * 0.7)
        g.addSublayer(shine)

        let rim = CAShapeLayer()
        rim.path = CGPath(ellipseIn: g.bounds.insetBy(dx: 1.5 * k, dy: 1.5 * k), transform: nil)
        rim.fillColor = nil
        rim.strokeColor = NSColor(red: 0.45, green: 0.53, blue: 0.75, alpha: 0.28).cgColor
        rim.lineWidth = 3 * k
        rim.contentsScale = scale
        g.addSublayer(rim)

        balls.append(g)
        textures.append(grain)
        return g
    }

    private static var grainCache: [Int: CGImage] = [:]

    /// Grain de neige dessiné une seule fois par taille : des centaines de petites bosses claires et sombres.
    private static func snowGrain(diameter: CGFloat) -> CGImage? {
        let size = max(8, Int(diameter))
        if let cached = grainCache[size] { return cached }
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let r = CGFloat(size) / 2
        for _ in 0..<(size * size / 60) {
            let a = CGFloat.random(in: 0...(2 * .pi))
            let d = r * sqrt(CGFloat.random(in: 0...1))
            let s = CGFloat.random(in: 1...4) * CGFloat(size) / 120
            let light = Bool.random()
            context.setFillColor(light ? CGColor(red: 1, green: 1, blue: 1, alpha: .random(in: 0.25...0.6))
                                       : CGColor(red: 0.5, green: 0.58, blue: 0.78, alpha: .random(in: 0.08...0.2)))
            context.fillEllipse(in: CGRect(x: r + cos(a) * d, y: r + sin(a) * d, width: s, height: s * 0.85))
        }
        let image = context.makeImage()
        grainCache[size] = image
        return image
    }

    /// Ombre douce là où une boule repose sur une autre : c'est elle qui donne le relief de la pile.
    private func crease(width: CGFloat, at center: CGPoint) -> CALayer {
        let c = CAGradientLayer()
        c.type = .radial
        c.colors = [NSColor(red: 0.3, green: 0.36, blue: 0.55, alpha: 0.4).cgColor,
                    NSColor(red: 0.3, green: 0.36, blue: 0.55, alpha: 0).cgColor]
        c.startPoint = CGPoint(x: 0.5, y: 0.5)
        c.endPoint = CGPoint(x: 1, y: 1)
        c.bounds = CGRect(x: 0, y: 0, width: width, height: width * 0.28)
        c.position = center
        return c
    }

    private func dot(radius: CGFloat, at center: CGPoint) -> CALayer {
        let d = CALayer()
        d.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        d.position = center
        d.cornerRadius = radius
        d.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor
        let gloss = CALayer()
        gloss.frame = CGRect(x: radius * 0.45, y: radius * 0.35, width: radius * 0.6, height: radius * 0.5)
        gloss.cornerRadius = radius * 0.25
        gloss.backgroundColor = NSColor(white: 1, alpha: 0.55).cgColor
        d.addSublayer(gloss)
        return d
    }

    /// Carotte accrochée par sa base : elle pousse vers l'extérieur.
    private func makeNose() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 28 * k, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 5 * k))
        path.addLine(to: CGPoint(x: 28 * k, y: 7 * k))
        path.closeSubpath()
        nose.path = path
        nose.bounds = CGRect(x: 0, y: 0, width: 28 * k, height: 7 * k)
        nose.anchorPoint = CGPoint(x: 1, y: 0.5)
        nose.position = CGPoint(x: -2 * k, y: 1.5 * k)
        nose.fillColor = NSColor(red: 0.98, green: 0.5, blue: 0.12, alpha: 1).cgColor
        nose.contentsScale = scale
        let ridges = CAShapeLayer()
        let lines = CGMutablePath()
        for x in [8.0, 14.0, 20.0] {
            lines.move(to: CGPoint(x: x * k, y: (1 + x / 28 * 4) * k))
            lines.addLine(to: CGPoint(x: (x + 1.5) * k, y: (6 - x / 28 * 0.5) * k))
        }
        ridges.path = lines
        ridges.strokeColor = NSColor(red: 0.75, green: 0.32, blue: 0.05, alpha: 0.8).cgColor
        ridges.lineWidth = 0.8 * k
        ridges.contentsScale = scale
        nose.addSublayer(ridges)
    }

    /// Écharpe rouge nouée au cou, avec un pan qui pend et deux rayures blanches au bout.
    private func makeScarf() {
        scarf.position = CGPoint(x: 0, y: c2 - r2 * 0.88)
        let red = NSColor(red: 0.85, green: 0.13, blue: 0.13, alpha: 1).cgColor

        let band = CALayer()
        band.bounds = CGRect(x: 0, y: 0, width: r2 * 1.75, height: 10 * k)
        band.cornerRadius = 5 * k
        band.masksToBounds = true
        band.backgroundColor = red
        band.addSublayer(knit(width: r2 * 1.75, height: 10 * k, vertical: false))
        scarf.addSublayer(band)

        scarfTail.bounds = CGRect(x: 0, y: 0, width: 10 * k, height: 38 * k)
        scarfTail.anchorPoint = CGPoint(x: 0.5, y: 0)
        scarfTail.position = CGPoint(x: -r2 * 0.35, y: 2 * k)
        scarfTail.transform = CATransform3DMakeRotation(0.12, 0, 0, 1)
        scarfTail.cornerRadius = 2 * k
        scarfTail.backgroundColor = red
        for y in [26.0, 31.0] {
            let stripe = CALayer()
            stripe.frame = CGRect(x: 0, y: y * k, width: 10 * k, height: 2.5 * k)
            stripe.backgroundColor = NSColor.white.cgColor
            scarfTail.addSublayer(stripe)
        }
        scarfTail.insertSublayer(knit(width: 10 * k, height: 38 * k, vertical: true), at: 0)
        let fringe = CAShapeLayer()
        let threads = CGMutablePath()
        for x in stride(from: 1.0, through: 9.0, by: 2) {
            threads.move(to: CGPoint(x: x * k, y: 38 * k))
            threads.addLine(to: CGPoint(x: x * k, y: 43 * k))
        }
        fringe.path = threads
        fringe.strokeColor = red
        fringe.lineWidth = 1.2 * k
        fringe.lineCap = .round
        fringe.contentsScale = scale
        scarfTail.addSublayer(fringe)
        scarf.addSublayer(scarfTail)
    }

    /// Mailles du tricot : de fines lignes plus sombres, en travers de la bande et en long sur le pan.
    private func knit(width: CGFloat, height: CGFloat, vertical: Bool) -> CALayer {
        let lines = CAShapeLayer()
        lines.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let path = CGMutablePath()
        let step = 2.5 * k
        if vertical {
            for y in stride(from: step, to: height, by: step) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        } else {
            for x in stride(from: step, to: width, by: step) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
        }
        lines.path = path
        lines.strokeColor = NSColor(red: 0.55, green: 0.05, blue: 0.07, alpha: 0.45).cgColor
        lines.lineWidth = 0.7 * k
        lines.contentsScale = scale
        return lines
    }

    /// Bras en branche, avec deux brindilles ; il pivote autour de l'épaule.
    private func makeArm(_ arm: CAShapeLayer, side: CGFloat) {
        let length = 52 * k
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: side * length, y: -length * 0.45))
        for (t, dy) in [(0.65, -12.0), (0.85, 8.0)] {
            let joint = CGPoint(x: side * length * t, y: -length * 0.45 * t)
            path.move(to: joint)
            path.addLine(to: CGPoint(x: joint.x + side * 12 * k, y: joint.y + dy * k))
        }
        arm.path = path
        arm.strokeColor = NSColor(red: 0.4, green: 0.25, blue: 0.13, alpha: 1).cgColor
        arm.lineWidth = 3.2 * k
        arm.lineCap = .round
        arm.fillColor = nil
        arm.contentsScale = scale
        arm.position = CGPoint(x: side * r2 * 0.85, y: c2 - 6 * k)
    }

    // MARK: - Outils d'animation

    private func basic(_ target: CALayer, _ keyPath: String, from: Any?, to: Any, at delay: CFTimeInterval,
                       duration: CFTimeInterval, timing: CAMediaTimingFunctionName = .easeInEaseOut) {
        let a = CABasicAnimation(keyPath: keyPath)
        a.fromValue = from
        a.toValue = to
        hold(a, at: delay, duration: duration)
        a.timingFunction = CAMediaTimingFunction(name: timing)
        target.add(a, forKey: "\(keyPath)-\(delay)")
    }

    /// Apparition avec rebond : la partie dépasse un peu sa taille, puis se stabilise.
    private func pop(_ target: CALayer, _ keyPath: String = "transform.scale", from: CGFloat = 0, at delay: CFTimeInterval) {
        let a = CASpringAnimation(keyPath: keyPath)
        a.fromValue = from
        a.toValue = 1
        a.damping = 9
        a.stiffness = 220
        a.mass = 0.8
        hold(a, at: delay, duration: a.settlingDuration)
        target.add(a, forKey: "pop-\(keyPath)-\(delay)")
    }

    /// Déplacement le long d'une courbe : la boule roule puis grimpe sur la pile.
    private func travel(_ target: CALayer, through points: [CGPoint], at delay: CFTimeInterval, duration: CFTimeInterval) {
        let path = CGMutablePath()
        path.move(to: points[0])
        var i = 1
        while i + 1 < points.count {
            path.addQuadCurve(to: points[i + 1], control: points[i])
            i += 2
        }
        let a = CAKeyframeAnimation(keyPath: "position")
        a.path = path
        a.calculationMode = .paced
        a.timingFunction = CAMediaTimingFunction(controlPoints: 0.45, 0, 0.3, 1)
        hold(a, at: delay, duration: duration)
        target.add(a, forKey: "travel-\(delay)")
    }

    private func roll(_ index: Int, turns: CGFloat, at delay: CFTimeInterval, duration: CFTimeInterval) {
        basic(textures[index], "transform.rotation.z", from: -turns * 2 * .pi, to: 0, at: delay, duration: duration,
              timing: .easeOut)
    }

    /// La boule touche la pile : elle s'écrase un instant, comme une vraie boule de neige.
    private func squash(_ target: CALayer, at delay: CFTimeInterval) {
        pop(target, "transform.scale.y", from: 0.8, at: delay)
    }

    private func hold(_ a: CAAnimation, at delay: CFTimeInterval, duration: CFTimeInterval) {
        a.beginTime = CACurrentMediaTime() + delay
        a.duration = duration
        a.fillMode = .both
        a.isRemovedOnCompletion = false
    }

    // MARK: - Construction

    static let buildDuration: CFTimeInterval = 7.5

    /// Comme dans Snowfall : deux boules roulent depuis la gauche en grossissant, la moyenne grimpe sur la grosse,
    /// la petite arrive de la droite et grimpe jusqu'en haut, puis le visage, l'écharpe et les bras apparaissent.
    func build() {
        let bottom = balls[0], middle = balls[1]
        basic(bottom, "position.x", from: -280 * k, to: 0, at: 0, duration: 2.2, timing: .easeOut)
        basic(bottom, "transform.scale", from: 0.3, to: 1, at: 0, duration: 2.2, timing: .easeOut)
        roll(0, turns: 2.5, at: 0, duration: 2.2)

        let besideBig = -(r1 + r2) * 0.98
        basic(middle, "position", from: NSValue(point: CGPoint(x: besideBig - 300 * k, y: 0)),
              to: NSValue(point: CGPoint(x: besideBig, y: 0)), at: 0.15, duration: 2.1, timing: .easeOut)
        basic(middle, "transform.scale", from: 0.3, to: 1, at: 0.15, duration: 2.1, timing: .easeOut)
        roll(1, turns: 3, at: 0.15, duration: 2.1)
        travel(middle, through: [CGPoint(x: besideBig, y: 0), CGPoint(x: -r1 * 1.05, y: -r1 * 1.55),
                                 CGPoint(x: 0, y: c2 + r2)], at: 2.45, duration: 1.0)
        roll(1, turns: 0.8, at: 2.45, duration: 1.0)
        squash(middle, at: 3.45)

        let besideStack = r1 + r3 * 1.05
        basic(head, "position", from: NSValue(point: CGPoint(x: besideStack + 300 * k, y: -r3)),
              to: NSValue(point: CGPoint(x: besideStack, y: -r3)), at: 2.6, duration: 1.6, timing: .easeOut)
        basic(head, "transform.scale", from: 0.4, to: 1, at: 2.6, duration: 1.6, timing: .easeOut)
        roll(2, turns: -2.5, at: 2.6, duration: 1.6)
        travel(head, through: [CGPoint(x: besideStack, y: -r3), CGPoint(x: r1 * 1.15, y: c2 + r2 * 0.6),
                               CGPoint(x: r2 * 0.95, y: c2 - r2 * 0.4), CGPoint(x: r2 * 0.6, y: c3 - r3 * 0.5),
                               CGPoint(x: 0, y: c3)], at: 4.3, duration: 1.1)
        roll(2, turns: -0.9, at: 4.3, duration: 1.1)
        squash(balls[2], at: 5.4)

        pop(eyes, at: 5.8)
        pop(nose, "transform.scale.x", at: 6.1)
        for (i, dot) in mouth.enumerated() { pop(dot, at: 6.3 + Double(i) * 0.06) }
        pop(scarf, "transform.scale.x", at: 6.5)
        for (i, b) in buttons.enumerated() { pop(b, at: 6.7 + Double(i) * 0.1) }
        let armsIn = CASpringAnimation(keyPath: "transform.rotation.z")
        for (arm, side, delay) in [(leftArm, 1.0, 7.0), (rightArm, -1.0, 7.15)] {
            let a = armsIn.copy() as! CASpringAnimation
            a.fromValue = side * .pi / 2
            a.toValue = 0
            a.damping = 7
            a.stiffness = 160
            hold(a, at: delay, duration: a.settlingDuration)
            arm.add(a, forKey: "arm-in")
        }
    }

    // MARK: - Vie

    /// Respiration et écharpe qui flotte, en boucle, une fois le bonhomme construit.
    func startIdle() {
        let breathe = CABasicAnimation(keyPath: "transform.scale.y")
        breathe.fromValue = 1
        breathe.toValue = 1.018
        breathe.duration = 1.8
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        body.add(breathe, forKey: "breathe")

        let flutter = CABasicAnimation(keyPath: "transform.rotation.z")
        flutter.fromValue = 0.06
        flutter.toValue = 0.2
        flutter.duration = 1.3
        flutter.autoreverses = true
        flutter.repeatCount = .infinity
        flutter.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scarfTail.add(flutter, forKey: "flutter")
    }

    func blink() {
        let a = CAKeyframeAnimation(keyPath: "transform.scale.y")
        a.values = [1, 0.1, 1]
        a.keyTimes = [0, 0.4, 1]
        a.duration = 0.22
        eyes.add(a, forKey: "blink")
    }

    /// Ses yeux vont d'un côté puis de l'autre.
    func lookAround() {
        let side: CGFloat = Bool.random() ? 1 : -1
        let look = CAKeyframeAnimation(keyPath: "transform.translation.x")
        look.values = [0, side * 3 * k, side * 3 * k, -side * 3 * k, -side * 3 * k, 0]
        look.keyTimes = [0, 0.12, 0.42, 0.55, 0.85, 1]
        look.duration = 2.6
        eyes.add(look, forKey: "look")
    }

    /// Il lève le bras gauche jusqu'au haut de la tête, se gratte en plissant les yeux, puis redescend.
    func scratchHead() {
        let shoulder = leftArm.position
        let rest = atan2(-0.45, -1.0)
        let target = atan2(c3 - r3 * 0.55 - shoulder.y, -r3 * 0.6 - shoulder.x)
        let reach = target - rest
        let arm = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        arm.values = [0, reach, reach - 0.18, reach, reach - 0.18, reach, reach - 0.18, reach, 0]
        arm.keyTimes = [0, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 1]
        arm.duration = 2.4
        arm.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        leftArm.add(arm, forKey: "scratch")
        let squint = CAKeyframeAnimation(keyPath: "transform.scale.y")
        squint.values = [1, 0.45, 0.45, 1]
        squint.keyTimes = [0, 0.25, 0.8, 1]
        squint.duration = 2.4
        eyes.add(squint, forKey: "squint")
    }

    /// Grand coucou : le bras droit monte haut et s'agite, les yeux sourient.
    func wave() {
        guard !melting else { return }
        let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        a.values = [0, -0.95, -0.5, -0.95, -0.5, -0.95, -0.5, 0]
        a.keyTimes = [0, 0.18, 0.3, 0.42, 0.54, 0.66, 0.8, 1]
        a.duration = 2
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rightArm.add(a, forKey: "wave")
        let smile = CAKeyframeAnimation(keyPath: "transform.scale.y")
        smile.values = [1, 0.55, 0.55, 1]
        smile.keyTimes = [0, 0.2, 0.8, 1]
        smile.duration = 2
        eyes.add(smile, forKey: "squint")
    }

    /// Appelé quand il lâche une boule de neige, avec la position de sa main dans le repère de l'écran.
    var onThrow: ((CGPoint) -> Void)?
    private lazy var handBall: CALayer = {
        let b = CAGradientLayer()
        b.type = .radial
        b.colors = [NSColor.white.cgColor, NSColor(red: 0.75, green: 0.81, blue: 0.93, alpha: 1).cgColor]
        b.startPoint = CGPoint(x: 0.35, y: 0.3)
        b.endPoint = CGPoint(x: 1.1, y: 1.1)
        b.bounds = CGRect(x: 0, y: 0, width: 12 * k, height: 12 * k)
        b.cornerRadius = 6 * k
        b.position = CGPoint(x: armLength, y: -armLength * 0.45)
        b.opacity = 0
        rightArm.addSublayer(b)
        return b
    }()
    private var armLength: CGFloat { 52 * k }

    /// Il ramasse une boule de neige, prend son élan et la lance ; la boule part au moment où le bras passe devant.
    func throwSnowball() -> TimeInterval {
        guard !melting else { return 0 }
        let duration = 1.6
        let releaseAt = 0.72
        let releaseAngle: CGFloat = 0.55
        let arm = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        arm.values = [0, 0.9, 0.9, -1.3, releaseAngle, 0]
        arm.keyTimes = [0, 0.2, 0.32, 0.6, NSNumber(value: releaseAt), 1]
        arm.duration = duration
        arm.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rightArm.add(arm, forKey: "throw")

        let carried = CAKeyframeAnimation(keyPath: "opacity")
        carried.values = [0, 0, 1, 1, 0, 0]
        carried.keyTimes = [0, 0.25, 0.32, NSNumber(value: releaseAt - 0.01), NSNumber(value: releaseAt), 1]
        carried.duration = duration
        handBall.add(carried, forKey: "carry")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration * releaseAt) { [weak self] in
            guard let self, !self.melting else { return }
            let tip = CGPoint(x: self.armLength, y: -self.armLength * 0.45)
            let turned = CGPoint(x: tip.x * cos(releaseAngle) - tip.y * sin(releaseAngle),
                                 y: tip.x * sin(releaseAngle) + tip.y * cos(releaseAngle))
            let hand = CGPoint(x: self.layer.position.x + self.rightArm.position.x + turned.x,
                               y: self.layer.position.y + self.rightArm.position.y + turned.y)
            self.onThrow?(hand)
        }
        return duration
    }

    /// Zone du Dock où il peut se promener en sautant, dans le repère de l'écran.
    var roam: ClosedRange<CGFloat> = 0...0

    /// Un, deux ou trois petits sauts : il s'écrase pour prendre son élan, s'étire en l'air,
    /// s'écrase en retombant, et avance un peu d'un côté ou de l'autre.
    func hop() {
        let count = Int.random(in: 1...3)
        let start = layer.position
        let step = CGFloat.random(in: 10...24) * k * (Bool.random() ? 1 : -1)
        let end = CGPoint(x: min(max(start.x + step * CGFloat(count), roam.lowerBound), roam.upperBound), y: start.y)
        let height = 26 * k
        let hopDuration = 0.55

        let path = CGMutablePath()
        path.move(to: start)
        for i in 0..<count {
            let from = start.x + (end.x - start.x) * CGFloat(i) / CGFloat(count)
            let to = start.x + (end.x - start.x) * CGFloat(i + 1) / CGFloat(count)
            path.addQuadCurve(to: CGPoint(x: to, y: start.y), control: CGPoint(x: (from + to) / 2, y: start.y - height * 2))
        }
        let move = CAKeyframeAnimation(keyPath: "position")
        move.path = path
        move.duration = hopDuration * Double(count)
        move.calculationMode = .cubicPaced
        layer.add(move, forKey: "hop")

        let squash = CAKeyframeAnimation(keyPath: "transform")
        var values: [NSValue] = []
        var times: [NSNumber] = []
        for i in 0..<count {
            let base = Double(i) / Double(count)
            let span = 1 / Double(count)
            for (t, sx, sy) in [(0.0, 1.0, 1.0), (0.12, 1.1, 0.85), (0.35, 0.94, 1.08),
                                (0.8, 1.0, 1.0), (0.9, 1.12, 0.84), (1.0, 1.0, 1.0)] {
                values.append(NSValue(caTransform3D: CATransform3DMakeScale(sx, sy, 1)))
                times.append(NSNumber(value: base + t * span))
            }
        }
        squash.values = values
        squash.keyTimes = times
        squash.duration = move.duration
        layer.add(squash, forKey: "squash")

        // La position finale devient la vraie : l'animation ne le ramène pas à son point de départ.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position = end
        CATransaction.commit()

        let armsUp = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        armsUp.values = [0, -0.35, 0]
        armsUp.duration = hopDuration
        armsUp.repeatCount = Float(count)
        rightArm.add(armsUp, forKey: "hop-arm")
        let leftUp = armsUp.copy() as! CAKeyframeAnimation
        leftUp.values = [0, 0.35, 0]
        leftUp.repeatCount = Float(count)
        leftArm.add(leftUp, forKey: "hop-arm")
    }

    /// Ses yeux montent vers le ciel, font le tour, puis reviennent.
    func rollEyes() {
        let a = CAKeyframeAnimation(keyPath: "transform.translation")
        a.values = [CGSize.zero, CGSize(width: 0, height: -3 * k), CGSize(width: 3 * k, height: -1.5 * k),
                    CGSize(width: 0, height: 1 * k), CGSize(width: -3 * k, height: -1.5 * k), CGSize.zero]
            .map { NSValue(size: $0) }
        a.duration = 1.6
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        eyes.add(a, forKey: "roll")
    }

    /// Petit dandinement de gauche à droite, les bras qui balancent.
    func wiggle() {
        let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        a.values = [0, 0.07, -0.07, 0.07, -0.07, 0]
        a.duration = 1.6
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(a, forKey: "wiggle")
        for (arm, sign) in [(leftArm, 1.0), (rightArm, -1.0)] {
            let swing = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            swing.values = [0, sign * 0.3, -sign * 0.15, sign * 0.3, -sign * 0.15, 0]
            swing.duration = 1.6
            arm.add(swing, forKey: "wiggle")
        }
    }

    /// Un geste au hasard, parfois deux à la suite. Renvoie sa durée, pour ne pas en lancer un autre par-dessus.
    func randomGesture() -> TimeInterval {
        if onThrow != nil, Int.random(in: 0..<5) == 0 { return throwSnowball() + 0.8 }
        switch Int.random(in: 0..<20) {
        case 0..<4: blink(); return 0.3
        case 4..<7: lookAround(); return 2.6
        case 7..<9: scratchHead(); return 2.4
        case 9..<12: wave(); return 2
        case 12..<16:
            hop()
            if Bool.random() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in self?.wave() }
                return 3.8
            }
            return 1.7
        case 16..<18: rollEyes(); return 1.6
        default: wiggle(); return 1.6
        }
    }

    // MARK: - Fonte

    static let meltDuration: CFTimeInterval = 18

    private var melting = false

    /// Il commence à s'affaisser et fait au revoir de la main, puis fond comme dans Snowfall : les bras tombent,
    /// la carotte tombe, les boules rapetissent, la tête glisse sur le côté, l'écharpe tombe à plat, et tout
    /// disparaît dans la neige.
    func melt() {
        melting = true
        body.removeAnimation(forKey: "breathe")
        scarfTail.removeAnimation(forKey: "flutter")
        [leftArm, rightArm, eyes].forEach { $0.removeAllAnimations() }

        let farewell = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        farewell.values = [0, -0.95, -0.45, -0.95, -0.45, -0.95, -0.45, -0.7]
        farewell.duration = 2.3
        farewell.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        hold(farewell, at: 0, duration: 2.3)
        rightArm.add(farewell, forKey: "farewell")
        let sad = CAKeyframeAnimation(keyPath: "transform.scale.y")
        sad.values = [1, 0.5, 0.5, 0.5]
        sad.duration = 2.3
        hold(sad, at: 0, duration: 2.3)
        eyes.add(sad, forKey: "farewell")

        let goodbye: CFTimeInterval = 2.4
        for (arm, side, delay) in [(rightArm, 1.0, goodbye), (leftArm, -1.0, goodbye + 1.2)] {
            basic(arm, "position", from: nil, to: NSValue(point: CGPoint(x: side * r1 * 0.9, y: -3 * k)),
                  at: delay, duration: 0.9, timing: .easeIn)
            basic(arm, "transform.rotation.z", from: nil, to: side * 0.45, at: delay, duration: 0.9, timing: .easeIn)
        }
        basic(nose, "position", from: nil, to: NSValue(point: CGPoint(x: -10 * k, y: -c3 - 4 * k)),
              at: goodbye + 2, duration: 0.8, timing: .easeIn)
        basic(nose, "transform.rotation.z", from: nil, to: 1.2, at: goodbye + 2, duration: 0.8, timing: .easeIn)
        for part in [eyes] + mouth { basic(part, "opacity", from: nil, to: 0, at: goodbye + 2.5, duration: 2) }
        for (i, b) in buttons.enumerated() {
            basic(b, "position.y", from: nil, to: -2 * k, at: goodbye + 3.5 + Double(i) * 0.6, duration: 0.7,
                  timing: .easeIn)
        }
        basic(body, "transform.scale", from: nil, to: 0.62, at: 0.5, duration: 10)
        basic(head, "position", from: nil, to: NSValue(point: CGPoint(x: -r1 * 1.6, y: -r3 * 0.9)),
              at: goodbye + 7, duration: 1.4, timing: .easeIn)
        basic(head, "transform.rotation.z", from: nil, to: -1.1, at: goodbye + 7, duration: 1.4, timing: .easeIn)
        basic(scarf, "position.y", from: nil, to: -4 * k, at: goodbye + 8.3, duration: 1, timing: .easeIn)
        basic(scarf, "transform.rotation.z", from: nil, to: 0.15, at: goodbye + 8.3, duration: 1, timing: .easeIn)
        for b in balls {
            basic(b, "transform.scale.y", from: nil, to: 0.15, at: goodbye + 9.5, duration: 4, timing: .easeIn)
        }
        basic(layer, "opacity", from: nil, to: 0, at: goodbye + 12.5, duration: 3)
    }
}
