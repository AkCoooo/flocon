import AppKit

/// Flocon rond. La profondeur donne sa taille, sa vitesse et sa transparence :
/// 0 au loin (passe derrière tout, ne se pose jamais), 2 tout près.
struct Flake {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    let radius: CGFloat
    var phase: CGFloat
    let depth: Int
}

/// Éclat de neige projeté quand un bloc s'écrase ; il rétrécit puis disparaît.
struct Shard {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    let radius: CGFloat
    var life: CGFloat
}

/// Un bord toujours devant les fenêtres (Dock, barre de menus) avec son tas de neige.
private struct Ledge {
    let rect: CGRect
    let pile: Pile

    func sameSpot(as other: CGRect) -> Bool {
        abs(rect.minX - other.minX) < 2 && abs(rect.minY - other.minY) < 2 && abs(rect.width - other.width) < 2
    }
}

final class SnowView: NSView {
    var flakesPerSecond: Double = 150 {
        didSet { updateBackdrop() }
    }
    /// Multiplie la neige gardée par chaque flocon qui se pose : les tas se forment en quelques secondes.
    var accumulationBoost: CGFloat = 1
    var snowmanEnabled = true {
        didSet { if !snowmanEnabled { meltSnowman() } }
    }
    var snowballsEnabled = true {
        didSet {
            snowman?.onThrow = snowballsEnabled ? { [weak self] hand in self?.launchSnowball(from: hand) } : nil
        }
    }
    var isPaused = false {
        didSet {
            updateBackdrop()
            // Sans neige, pas de bonhomme : celui qui est là fond.
            if isPaused { meltSnowman() } else { setFrameRate(Self.activeFPS) }
        }
    }

    private static let activeFPS: Double = 24
    private static let idleFPS: Double = 2
    private static let gravity: CGFloat = 1600
    private static let shardLifetime: CGFloat = 0.6
    /// Rayon des coins des fenêtres de macOS 26.
    private static let windowCornerRadius: CGFloat = 20

    private var flakes: [Flake] = []
    private var clumps: [Clump] = []
    private var shards: [Shard] = []
    /// Fenêtres puis icônes du bureau, de la plus en avant à la plus en arrière.
    private var surfaces: [TrackedWindow] = []
    private var piles: [CGWindowID: Pile] = [:]
    /// Tas de chaque surface, dans le même ordre que `surfaces` : pas de recherche par identifiant à chaque flocon.
    private var surfacePiles: [Pile?] = []
    private var icicles: [CGWindowID: Icicles] = [:]
    /// Bas de l'écran : derrière les fenêtres, comme le bureau.
    private var floor: Pile?
    private var dock: Ledge?
    /// Coin haut gauche de cet écran, dans les coordonnées globales des fenêtres.
    private var screenOrigin: CGPoint = .zero

    /// Un seul bonhomme pour tous les écrans : sur celui qui a le Dock.
    private static var snowmanOwner: SnowView?
    private var snowman: Snowman?
    private var snowmanDock: CGRect?
    private var snowmanMeltsAt: TimeInterval = 0
    private var snowmanMelting = false
    private var nextGestureAt: TimeInterval = 0
    private var snowmanBuiltAt: TimeInterval = 0
    private var snowmanIdle = false
    private var nextSnowmanAt = ProcessInfo.processInfo.systemUptime + 20
    private var spawnBudget: Double = 0
    private var tickCount = 0
    private var pilesChanged = true
    private var timer: Timer?
    private var fps: Double = 0

    /// Tas en volume : une ombre douce, un corps gris-bleu, puis le dessus blanc.
    private let pileShadowLayer = CAShapeLayer()
    private let pileBodyLayer = CAShapeLayer()
    private let pileTopLayer = CAShapeLayer()
    /// Stalactites : glace bleue translucide autour d'un cœur blanc.
    private let iceContainer = CALayer()
    /// Liseré de givre le long du bord des fenêtres, là où pendent les stalactites.
    private let frostLayer = CAShapeLayer()
    private let clumpContainer = CALayer()
    private let flakeLayers = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    private let shardLayer = CAShapeLayer()
    /// Flocons du fond et gros cristaux : ils ne se posent jamais, la carte graphique les anime seule.
    private let backdrop = CAEmitterLayer()

    /// Plein écran : peu de flocons, un tas fin en bas, rien sur la fenêtre elle-même.
    private var isFullScreen = false
    private weak var screen: NSScreen?

    override var isFlipped: Bool { true }

    private static func isDesktopIcon(_ id: CGWindowID) -> Bool { id >= 0x8000_0000 }

    /// La carte graphique peint les formes : le processeur ne fait que décrire leur contour.
    func start(screen: NSScreen, screenOrigin: CGPoint) {
        self.screen = screen
        self.screenOrigin = screenOrigin

        let root = CALayer()
        root.isGeometryFlipped = true
        layer = root
        wantsLayer = true

        configure(pileShadowLayer, fill: NSColor(red: 0.1, green: 0.15, blue: 0.3, alpha: 0.22).cgColor, offsetY: 2, in: root)
        configure(pileBodyLayer, fill: NSColor(red: 0.8, green: 0.86, blue: 0.96, alpha: 1).cgColor, in: root)
        configure(pileTopLayer, fill: NSColor.white.cgColor, in: root)
        iceContainer.frame = bounds
        root.addSublayer(iceContainer)
        configure(frostLayer, fill: NSColor(white: 1, alpha: 0.92).cgColor, in: root)
        clumpContainer.frame = bounds
        root.addSublayer(clumpContainer)
        // Un flocon rond = un trait de longueur nulle aux bouts arrondis : 2 éléments de tracé au lieu de 6 pour
        // une ellipse. Les flocons proches sont de petites étoiles, tracées au trait.
        for (depth, flakeLayer) in flakeLayers.enumerated() {
            configure(flakeLayer, fill: nil, in: root)
            flakeLayer.opacity = [0.4, 0.75, 1][depth]
            flakeLayer.strokeColor = NSColor.white.cgColor
            flakeLayer.lineWidth = [2.0, 3.4, 1.3][depth]
            flakeLayer.lineCap = .round
        }
        configure(shardLayer, fill: NSColor.white.cgColor, in: root)
        configureBackdrop(in: root)

        floor = Pile(minX: 0, width: bounds.width, maxHeight: 30)
        refreshSurfaces()
        setFrameRate(Self.activeFPS)
    }

    private func configure(_ shape: CAShapeLayer, fill: CGColor?, offsetY: CGFloat = 0, in root: CALayer) {
        shape.frame = bounds.offsetBy(dx: 0, dy: offsetY)
        shape.contentsScale = screen?.backingScaleFactor ?? 2
        shape.fillColor = fill
        shape.actions = ["path": NSNull()]
        root.addSublayer(shape)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        snowman?.layer.removeFromSuperlayer()
        clearSnowman(nextIn: 20)
    }

    private func setFrameRate(_ newFPS: Double) {
        guard newFPS != fps else { return }
        fps = newFPS
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1 / newFPS, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        let dt = CGFloat(1 / fps)
        tickCount += 1
        if fps == Self.idleFPS || tickCount % 5 == 0 { refreshSurfaces() }
        if tickCount % 30 == 0 {
            growIcicles(seconds: CGFloat(30 / fps))
            updateSnowman()
        }
        if !isPaused { spawn(dt: dt) }
        moveFlakes(dt: dt)
        moveClumps(dt: dt)
        moveShards(dt: dt)
        render()
        // Neige arrêtée et plus rien en l'air : on ne fait plus que surveiller les fenêtres.
        let idle = isPaused && flakes.isEmpty && clumps.isEmpty && shards.isEmpty
        setFrameRate(idle ? Self.idleFPS : Self.activeFPS)
    }

    // MARK: - Chute

    /// Seuls les flocons qui peuvent se poser sont calculés ici ; ceux du fond sont confiés au générateur de particules.
    private func spawn(dt: CGFloat) {
        spawnBudget += currentRate * Self.landingShare * Double(dt)
        while spawnBudget >= 1 {
            spawnBudget -= 1
            let near = Double.random(in: 0..<1) < 0.36
            flakes.append(Flake(x: .random(in: 0...bounds.width), y: -5, vx: 0,
                                vy: near ? .random(in: 60...88) : .random(in: 40...62),
                                radius: near ? .random(in: 2.2...3.4) : .random(in: 1.3...2.2),
                                phase: .random(in: 0...(2 * .pi)), depth: near ? 2 : 1))
        }
    }

    /// Part des flocons qui tombent au premier plan et peuvent se poser ; le reste est le fond, sur la carte graphique.
    private static let landingShare = 0.55

    private var currentRate: Double {
        isPaused ? 0 : flakesPerSecond * (isFullScreen ? 0.2 : 1)
    }

    private func configureBackdrop(in root: CALayer) {
        backdrop.frame = bounds
        backdrop.emitterShape = .line
        backdrop.emitterPosition = CGPoint(x: bounds.midX, y: -20)
        backdrop.emitterSize = CGSize(width: bounds.width, height: 1)
        let fall = bounds.height + 60

        let far = CAEmitterCell()
        far.contents = Sprites.softDot
        far.velocity = 38
        far.velocityRange = 8
        far.emissionLongitude = .pi
        far.emissionRange = 0.12
        far.lifetime = Float(fall / 30)
        far.scale = 0.16
        far.scaleRange = 0.05
        far.alphaSpeed = 0
        far.color = NSColor(white: 1, alpha: 0.5).cgColor
        far.name = "far"

        let crystal = CAEmitterCell()
        crystal.contents = Sprites.crystal
        crystal.velocity = 28
        crystal.velocityRange = 7
        crystal.emissionLongitude = .pi
        crystal.emissionRange = 0.15
        crystal.lifetime = Float(fall / 21)
        crystal.scale = 0.42
        crystal.scaleRange = 0.17
        crystal.spin = 0
        crystal.spinRange = 1.2
        crystal.color = NSColor(white: 1, alpha: 0.6).cgColor
        crystal.name = "crystal"

        backdrop.emitterCells = [far, crystal]
        root.addSublayer(backdrop)
        updateBackdrop()
    }

    /// Le fond suit le menu : quantité de neige, pause et plein écran.
    func updateBackdrop() {
        backdrop.setValue(Float(currentRate * 0.3), forKeyPath: "emitterCells.far.birthRate")
        backdrop.setValue(Float(currentRate / 900), forKeyPath: "emitterCells.crystal.birthRate")
    }

    private func moveFlakes(dt: CGFloat) {
        var kept: [Flake] = []
        kept.reserveCapacity(flakes.count)
        for flake in flakes {
            var f = flake
            let previousY = f.y
            f.phase += dt * 1.5
            f.x += (f.vx + sin(f.phase) * (f.depth == 2 ? 24 : 16)) * dt
            f.y += f.vy * dt
            f.vx *= 0.96
            if land(f, from: previousY) || f.y > bounds.height { continue }
            kept.append(f)
        }
        flakes = kept
    }

    // MARK: - Atterrissage

    /// Le flocon se pose sur la première surface qu'il traverse et qu'aucune fenêtre ne cache.
    /// Dans un coin trop raide, il glisse et continue sa chute.
    private func land(_ f: Flake, from previousY: CGFloat) -> Bool {
        if let dock, crosses(f, from: previousY, ledge: dock) {
            return deposit(f, on: dock.pile, amount: 0.9)
        }
        for (index, surface) in surfaces.enumerated() {
            guard let pile = surfacePiles[index], pile.contains(x: f.x), pile.canHold(atX: f.x) else { continue }
            let top = surface.frame.minY + pile.surfaceOffset(atX: f.x)
            if previousY < top, f.y >= top, !isCovered(CGPoint(x: f.x, y: top), byWindowsBefore: index) {
                return deposit(f, on: pile, amount: 1.1)
            }
        }
        if let floor {
            let top = bounds.height + floor.surfaceOffset(atX: f.x)
            let point = CGPoint(x: f.x, y: top)
            if f.y >= top, !isCovered(point, byWindowsBefore: surfaces.count), !isBehindDock(point) {
                return deposit(f, on: floor, amount: 1.4)
            }
        }
        return false
    }

    private func crosses(_ f: Flake, from previousY: CGFloat, ledge: Ledge) -> Bool {
        guard ledge.pile.contains(x: f.x), ledge.pile.canHold(atX: f.x) else { return false }
        let top = ledge.rect.minY + ledge.pile.surfaceOffset(atX: f.x)
        return previousY < top && f.y >= top
    }

    private func deposit(_ f: Flake, on pile: Pile, amount: CGFloat) -> Bool {
        pile.add(atX: f.x, amount: f.radius * amount * accumulationBoost)
        pilesChanged = true
        return true
    }

    private func isCovered(_ point: CGPoint, byWindowsBefore index: Int) -> Bool {
        surfaces.prefix(index).contains { $0.frame.contains(point) }
    }

    /// Le Dock est devant le sol : la neige du bas de l'écran passe derrière lui.
    private func isBehindDock(_ point: CGPoint) -> Bool {
        guard let rect = dock?.rect else { return false }
        return point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY
    }

    // MARK: - Surfaces

    private func toLocal(_ rect: CGRect) -> CGRect {
        rect.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y)
    }

    private func refreshSurfaces() {
        let onScreen = WindowTracker.visibleWindows()
            .map { TrackedWindow(id: $0.id, frame: toLocal($0.frame)) }
            .filter { $0.frame.intersects(bounds) }
        // Une fenêtre qui couvre tout l'écran n'a pas de dessus visible : les autres, par-dessus, gardent leur neige.
        let coversScreen = { (window: TrackedWindow) in window.frame.contains(self.bounds.insetBy(dx: 1, dy: 1)) }
        let hasCoveringWindow = onScreen.contains(where: coversScreen)
        let fullScreen = hasCoveringWindow && FullScreenDetector.isFrontAppFullScreen()
        var current = onScreen.filter { !coversScreen($0) }
        if !hasCoveringWindow {
            current += (WindowTracker.desktopWidgets() + DesktopIcons.frames())
                .map { TrackedWindow(id: $0.id, frame: toLocal($0.frame)) }
                .filter { $0.frame.intersects(bounds) }
        }
        let currentFrames = Dictionary(current.map { ($0.id, $0.frame) }, uniquingKeysWith: { first, _ in first })

        if fullScreen != isFullScreen {
            isFullScreen = fullScreen
            updateBackdrop()
        }
        // La barre du Dock a des coins arrondis à environ 30 % de sa hauteur.
        let bar = dockRect()
        dock = updated(dock, to: bar, maxHeight: 22, cornerRadius: (bar?.height ?? 0) * 0.3)
        // Derrière le Dock, une congère qui monte un peu au-dessus de lui, comme dans Snowfall.
        let floorHeight = fullScreen ? 8 : dock.map { bounds.height - $0.rect.minY + 14 } ?? 30
        if floor?.maxHeight != floorHeight {
            floor = Pile(minX: 0, width: bounds.width, maxHeight: floorHeight)
            pilesChanged = true
        }

        for old in surfaces where currentFrames[old.id] != old.frame {
            let pile = piles.removeValue(forKey: old.id)
            let spikes = icicles.removeValue(forKey: old.id)
            spikes?.layers.forEach { $0.removeFromSuperlayer() }
            // En passant en plein écran, les tas disparaissent sans pluie de flocons.
            guard !fullScreen else { continue }
            if let pile { collapse(pile, top: old.frame.minY) }
            if let spikes { snap(spikes, bottom: old.frame.maxY) }
        }
        for surface in current where piles[surface.id] == nil {
            let isIcon = Self.isDesktopIcon(surface.id)
            // Icônes et widgets vivent sur le bureau ; les widgets, plus grands, ont des coins plus ronds.
            let radius = !isIcon ? Self.windowCornerRadius : surface.frame.width < 150 ? 8 : 22
            piles[surface.id] = Pile(minX: surface.frame.minX, width: surface.frame.width,
                                     maxHeight: isIcon ? 14 : 24, cornerRadius: radius)
            if !isIcon {
                let spikes = Icicles(frame: surface.frame, contentsScale: screen?.backingScaleFactor ?? 2)
                spikes.layers.forEach(iceContainer.addSublayer)
                icicles[surface.id] = spikes
            }
        }
        if current.map(\.id) != surfaces.map(\.id) { pilesChanged = true }
        surfaces = current
        surfacePiles = current.map { piles[$0.id] }
    }

    /// Sans autorisation Accessibilité, la largeur du Dock est inconnue : pas de tas plutôt qu'un tas dans le vide.
    /// Le cadre de la liste du Dock est sa barre visible, quelle que soit la taille choisie.
    private func dockRect() -> CGRect? {
        guard !isFullScreen, let bar = DockLocator.frame().map(toLocal), bar.intersects(bounds) else { return nil }
        // Base enfoncée de 2 points dans la barre : sinon un liseré de vide reste visible sous la neige.
        return CGRect(x: bar.minX, y: bar.minY + 2, width: bar.width, height: bar.height - 2)
    }

    /// Le bord a bougé ou disparu : sa neige retombe et un nouveau tas commence.
    private func updated(_ ledge: Ledge?, to rect: CGRect?, maxHeight: CGFloat, cornerRadius: CGFloat) -> Ledge? {
        if let ledge, let rect, ledge.sameSpot(as: rect) { return ledge }
        if ledge == nil, rect == nil { return nil }
        if let ledge { collapse(ledge.pile, top: ledge.rect.minY) }
        pilesChanged = true
        return rect.map {
            Ledge(rect: $0, pile: Pile(minX: $0.minX, width: $0.width, maxHeight: maxHeight, cornerRadius: cornerRadius))
        }
    }

    private func growIcicles(seconds: CGFloat) {
        for (id, spikes) in icicles {
            guard let pile = piles[id] else { continue }
            if spikes.grow(seconds: seconds, pile: pile) { pilesChanged = true }
        }
    }

    // MARK: - Effondrement

    /// La fenêtre a bougé ou disparu : son tas se casse en mottes arrondies qui tombent.
    private func collapse(_ pile: Pile, top: CGFloat) {
        pilesChanged = true
        var start = 0
        while start < pile.heights.count {
            let end = min(start + Int.random(in: 8...18), pile.heights.count)
            let heights = (start..<end).map(pile.displayHeight)
            let thickness = heights.reduce(0, +) / CGFloat(heights.count)
            if thickness > 1.5, clumps.count < 80 {
                let width = CGFloat(end - start) * Pile.binWidth
                let size = CGSize(width: max(width, 8), height: max(thickness * 1.1, 6))
                let clump = Clump(center: CGPoint(x: pile.columnX(start) + width / 2,
                                                  y: top + pile.drop(start) - size.height / 2),
                                  size: size, scale: screen?.backingScaleFactor ?? 2)
                clumpContainer.addSublayer(clump.layer)
                clumps.append(clump)
            }
            start = end
        }
    }

    private func groundLevel(atX x: CGFloat) -> CGFloat {
        if let rect = dock?.rect, rect.minX...rect.maxX ~= x { return rect.minY }
        return bounds.height
    }

    private func moveClumps(dt: CGFloat) {
        guard !clumps.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clumps = clumps.filter { clump in
            let wasFalling = clump.landedFor == nil
            let alive = clump.step(dt: dt, gravity: Self.gravity, ground: groundLevel(atX: clump.position.x))
            if wasFalling, clump.landedFor != nil {
                splat(clump)
                bury(clump)
            }
            if !alive { clump.layer.removeFromSuperlayer() }
            return alive
        }
        CATransaction.commit()
    }

    /// La motte rejoint le tas où elle tombe ; le tas garde sa hauteur maximale, le surplus disparaît.
    private func bury(_ clump: Clump) {
        let size = clump.layer.bounds.size
        let pile: Pile?
        if let dock, dock.rect.minX...dock.rect.maxX ~= clump.position.x { pile = dock.pile } else { pile = floor }
        guard let pile else { return }
        var x = clump.position.x - size.width / 2
        while x < clump.position.x + size.width / 2 {
            pile.add(atX: x, amount: size.height * 0.5)
            x += Pile.binWidth
        }
        pilesChanged = true
    }

    // MARK: - Bonhomme de neige

    /// Il apparaît sur le Dock de temps en temps, reste un moment en saluant, puis fond.
    private func updateSnowman() {
        let now = ProcessInfo.processInfo.systemUptime
        if let snowman {
            // Le Dock a bougé ou disparu : le bonhomme n'a plus de sol, il s'en va.
            guard let dock, snowmanDock == dock.rect else {
                snowman.layer.removeFromSuperlayer()
                clearSnowman(nextIn: 30)
                return
            }
            if now >= snowmanMeltsAt + Snowman.meltDuration {
                snowman.layer.removeFromSuperlayer()
                clearSnowman(nextIn: .random(in: 90...240))
            } else if now >= snowmanMeltsAt, !snowmanMelting {
                snowmanMelting = true
                snowman.melt()
            } else if now < snowmanMeltsAt, now >= snowmanBuiltAt {
                if !snowmanIdle {
                    snowmanIdle = true
                    snowman.startIdle()
                }
                if now >= nextGestureAt {
                    nextGestureAt = now + snowman.randomGesture() + .random(in: 0.8...2.5)
                }
            }
            return
        }
        guard snowmanEnabled, !isPaused, !isFullScreen, now >= nextSnowmanAt, Self.snowmanOwner == nil else { return }
        buildSnowman()
    }

    // MARK: - Boules de neige

    /// Une cible au hasard : une fenêtre visible, une icône ou un widget au-dessus du bonhomme, sinon le ciel.
    private func snowballTarget(above hand: CGPoint) -> CGPoint {
        let candidates = surfaces.enumerated().filter { index, surface in
            surface.frame.midY < hand.y - 60 &&
                !isCovered(CGPoint(x: surface.frame.midX, y: surface.frame.minY + 20), byWindowsBefore: index)
        }
        guard let (_, target) = candidates.randomElement() else {
            return CGPoint(x: .random(in: bounds.width * 0.2...bounds.width * 0.8), y: .random(in: 120...bounds.height * 0.5))
        }
        let f = target.frame
        if Self.isDesktopIcon(target.id) { return CGPoint(x: f.midX, y: f.minY + f.height * 0.4) }
        let margin = min(40, f.width / 3)
        return CGPoint(x: .random(in: (f.minX + margin)...(f.maxX - margin)),
                       y: f.minY + .random(in: 30...max(31, min(160, f.height * 0.5))))
    }

    /// La boule part de la main en cloche jusqu'à sa cible.
    private func launchSnowball(from hand: CGPoint) {
        let target = snowballTarget(above: hand)
        let ball = CAGradientLayer()
        ball.type = .radial
        ball.colors = [NSColor.white.cgColor, NSColor(red: 0.75, green: 0.81, blue: 0.93, alpha: 1).cgColor]
        ball.startPoint = CGPoint(x: 0.35, y: 0.3)
        ball.endPoint = CGPoint(x: 1.1, y: 1.1)
        ball.bounds = CGRect(x: 0, y: 0, width: 13, height: 13)
        ball.cornerRadius = 6.5
        ball.position = target
        ball.actions = ["position": NSNull()]

        let distance = hypot(target.x - hand.x, target.y - hand.y)
        let path = CGMutablePath()
        path.move(to: hand)
        path.addQuadCurve(to: target, control: CGPoint(x: (hand.x + target.x) / 2,
                                                       y: min(hand.y, target.y) - distance * 0.35))
        let flight = CAKeyframeAnimation(keyPath: "position")
        flight.path = path
        flight.duration = min(1.1, max(0.45, Double(distance) / 1100))

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak ball] in
            ball?.removeFromSuperlayer()
            self?.splatSnowball(at: target)
        }
        clumpContainer.addSublayer(ball)
        ball.add(flight, forKey: "flight")
        CATransaction.commit()
    }

    /// Splash : un petit nuage de neige collé à la cible, des éclaboussures, puis il glisse et fond.
    private func splatSnowball(at point: CGPoint) {
        let splat = CALayer()
        splat.position = point
        splat.bounds = .zero
        for (dx, dy, r) in [(0.0, 0.0, 11.0), (-10.0, 3.0, 8.0), (10.0, 2.0, 8.5), (-4.0, -8.0, 8.0),
                            (6.0, -7.0, 7.0), (-14.0, -3.0, 5.0), (15.0, -4.0, 5.5), (2.0, 9.0, 7.0)] {
            let puff = CAGradientLayer()
            puff.type = .radial
            puff.colors = [NSColor.white.cgColor, NSColor(red: 0.84, green: 0.88, blue: 0.97, alpha: 1).cgColor,
                           NSColor(red: 0.66, green: 0.73, blue: 0.88, alpha: 1).cgColor]
            puff.locations = [0, 0.6, 1]
            puff.startPoint = CGPoint(x: 0.35, y: 0.3)
            puff.endPoint = CGPoint(x: 1.1, y: 1.1)
            puff.bounds = CGRect(x: 0, y: 0, width: r * 2, height: r * 2)
            puff.cornerRadius = r
            puff.position = CGPoint(x: dx, y: dy)
            splat.addSublayer(puff)
        }
        let pop = CASpringAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.3
        pop.toValue = 1
        pop.damping = 10
        pop.stiffness = 300
        pop.duration = pop.settlingDuration
        splat.add(pop, forKey: "pop")

        let life: CFTimeInterval = 3.4
        let slide = CAKeyframeAnimation(keyPath: "transform.translation.y")
        slide.values = [0, 0, 26]
        slide.keyTimes = [0, 0.4, 1]
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.7, 1]
        let melt = CAAnimationGroup()
        melt.animations = [slide, fade]
        melt.duration = life
        melt.timingFunction = CAMediaTimingFunction(name: .easeIn)
        melt.fillMode = .forwards
        melt.isRemovedOnCompletion = false
        splat.add(melt, forKey: "melt")
        clumpContainer.addSublayer(splat)
        DispatchQueue.main.asyncAfter(deadline: .now() + life) { splat.removeFromSuperlayer() }

        for _ in 0..<10 {
            let drop = CALayer()
            let r = CGFloat.random(in: 1.5...3.2)
            drop.bounds = CGRect(x: 0, y: 0, width: r * 2, height: r * 2)
            drop.cornerRadius = r
            drop.backgroundColor = NSColor.white.cgColor
            drop.position = point
            drop.opacity = 0
            let angle = CGFloat.random(in: (-.pi * 0.95)...(-.pi * 0.05))
            let reach = CGFloat.random(in: 18...40)
            let fly = CABasicAnimation(keyPath: "position")
            fly.fromValue = NSValue(point: point)
            fly.toValue = NSValue(point: CGPoint(x: point.x + cos(angle) * reach, y: point.y + sin(angle) * reach + 10))
            let show = CAKeyframeAnimation(keyPath: "opacity")
            show.values = [1, 1, 0]
            show.keyTimes = [0, 0.6, 1]
            let group = CAAnimationGroup()
            group.animations = [fly, show]
            group.duration = 0.55
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            drop.add(group, forKey: "fly")
            clumpContainer.addSublayer(drop)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { drop.removeFromSuperlayer() }
        }
    }

    /// Construit un bonhomme tout de suite, si ce écran a le Dock.
    func buildSnowmanNow() {
        guard !isPaused, snowman == nil, Self.snowmanOwner == nil else { return }
        buildSnowman()
    }

    private func buildSnowman() {
        guard let dock, dock.rect.width > 260 else { return }
        let x = CGFloat.random(in: (dock.rect.minX + 110)...(dock.rect.maxX - 110))
        let foot = CGPoint(x: x, y: dock.rect.minY - dock.pile.height(atX: x) + 3)
        let made = Snowman(at: foot, size: min(1.3, max(0.7, dock.rect.height / 86)),
                           contentsScale: screen?.backingScaleFactor ?? 2)
        made.roam = (dock.rect.minX + 70)...(dock.rect.maxX - 70)
        if snowballsEnabled { made.onThrow = { [weak self] hand in self?.launchSnowball(from: hand) } }
        clumpContainer.addSublayer(made.layer)
        made.build()
        snowman = made
        snowmanDock = dock.rect
        Self.snowmanOwner = self
        let now = ProcessInfo.processInfo.systemUptime
        // 20 s en tout, construction comprise, avant de dire au revoir et de fondre.
        snowmanMeltsAt = now + 20
        snowmanBuiltAt = now + Snowman.buildDuration
        nextGestureAt = snowmanBuiltAt + 1
    }

    private func meltSnowman() {
        guard snowman != nil, !snowmanMelting else { return }
        snowmanMeltsAt = ProcessInfo.processInfo.systemUptime
        updateSnowman()
    }

    private func clearSnowman(nextIn delay: TimeInterval) {
        snowman = nil
        snowmanMelting = false
        snowmanIdle = false
        snowmanDock = nil
        if Self.snowmanOwner === self { Self.snowmanOwner = nil }
        nextSnowmanAt = ProcessInfo.processInfo.systemUptime + delay
    }

    /// La motte touche le sol : quelques éclats giclent sur les côtés.
    private func splat(_ clump: Clump) {
        let size = clump.layer.bounds.size
        for _ in 0..<min(14, max(3, Int(size.width / 6))) {
            shards.append(Shard(
                x: clump.position.x + .random(in: -size.width / 2...size.width / 2),
                y: clump.position.y + size.height / 2 - 2,
                vx: .random(in: -120...120),
                vy: .random(in: -180 ... -50),
                radius: .random(in: 1.2...2.8),
                life: Self.shardLifetime * .random(in: 0.6...1)
            ))
        }
    }

    private func moveShards(dt: CGFloat) {
        shards = shards.compactMap { shard in
            var s = shard
            s.life -= dt
            guard s.life > 0 else { return nil }
            s.vy += Self.gravity * 0.6 * dt
            s.x += s.vx * dt
            s.y = min(s.y + s.vy * dt, groundLevel(atX: s.x))
            return s
        }
    }

    /// Les stalactites cassent : quelques morceaux tombent.
    private func snap(_ spikes: Icicles, bottom: CGFloat) {
        for spike in spikes.spikes where spike.length > 2 {
            for _ in 0..<Int(spike.length / 4) + 1 {
                shards.append(Shard(x: spike.x, y: bottom + .random(in: 0...spike.length),
                                    vx: .random(in: -30...30), vy: .random(in: 0...80),
                                    radius: .random(in: 1...2), life: Self.shardLifetime * 1.5))
            }
        }
    }

    // MARK: - Dessin

    private func render() {
        let flakePaths = [CGMutablePath(), CGMutablePath(), CGMutablePath()]
        for f in flakes {
            if f.depth == 2 {
                addStar(at: CGPoint(x: f.x, y: f.y), radius: f.radius * 1.3, angle: f.phase * 0.3, to: flakePaths[2])
            } else {
                flakePaths[f.depth].move(to: CGPoint(x: f.x, y: f.y))
                flakePaths[f.depth].addLine(to: CGPoint(x: f.x + 0.01, y: f.y))
            }
        }
        for (layer, path) in zip(flakeLayers, flakePaths) { layer.path = path }
        if !shards.isEmpty || shardLayer.path != nil {
            let shardPath = CGMutablePath()
            for s in shards {
                let r = s.radius * s.life / Self.shardLifetime
                shardPath.addEllipse(in: CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2))
            }
            shardLayer.path = shards.isEmpty ? nil : shardPath
        }


        // Les tas changent lentement : on ne les redécrit que s'ils ont bougé, et au plus 7 fois par seconde.
        guard pilesChanged, tickCount % 4 == 0 || fps == Self.idleFPS else { return }
        pilesChanged = false
        let bodyPath = CGMutablePath()
        let topPath = CGMutablePath()
        let frostPath = CGMutablePath()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, surface) in surfaces.enumerated() {
            if let pile = piles[surface.id] {
                addPile(pile, top: surface.frame.minY, hiddenBehind: index, body: bodyPath, highlight: topPath)
            }
            if let spikes = icicles[surface.id] {
                layoutIcicles(spikes, bottom: surface.frame.maxY, hiddenBehind: index, frost: frostPath)
            }
        }
        if let floor {
            addPile(floor, top: bounds.height, hiddenBehind: surfaces.count, alsoHiddenBehindDock: true,
                    body: bodyPath, highlight: topPath)
        }
        if let ledge = dock {
            addPile(ledge.pile, top: ledge.rect.minY, hiddenBehind: 0, body: bodyPath, highlight: topPath)
        }
        pileShadowLayer.path = bodyPath
        pileBodyLayer.path = bodyPath
        pileTopLayer.path = topPath
        CATransaction.commit()
        frostLayer.path = frostPath
    }

    /// Petite étoile à six branches : trois traits croisés.
    private func addStar(at center: CGPoint, radius: CGFloat, angle: CGFloat, to path: CGMutablePath) {
        for arm in 0..<3 {
            let a = angle + CGFloat(arm) * .pi / 3
            let dx = cos(a) * radius
            let dy = sin(a) * radius
            path.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
            path.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
        }
    }

    /// Place les stalactites sous la fenêtre, et un liseré de givre là où elles pendent.
    private func layoutIcicles(_ spikes: Icicles, bottom: CGFloat, hiddenBehind index: Int, frost: CGMutablePath) {
        let hidden = { (x: CGFloat) in self.isCovered(CGPoint(x: x, y: bottom + 1), byWindowsBefore: index) }
        spikes.layout(bottom: bottom, isHidden: hidden)
        let visible = spikes.spikes.filter { $0.length > 0.5 && !hidden($0.x) }
        guard let first = visible.first, let last = visible.last else { return }
        let thickness = min(3, (visible.map(\.length).max() ?? 0) / 4)
        guard thickness > 0.5 else { return }
        frost.addRoundedRect(in: CGRect(x: first.x - 6, y: bottom - 1, width: last.x - first.x + 12, height: thickness + 1),
                             cornerWidth: thickness / 2, cornerHeight: thickness / 2)
    }

    /// Courbe lissée qui passe par le haut des colonnes, coupée là où une fenêtre devant la cache.
    /// Le corps va jusqu'à la base ; le dessus blanc n'en couvre que la partie haute.
    private func addPile(_ pile: Pile, top: CGFloat, hiddenBehind index: Int, alsoHiddenBehindDock: Bool = false,
                         body: CGMutablePath, highlight: CGMutablePath) {
        var points: [CGPoint] = []
        var bases: [CGFloat] = []
        var highlightBases: [CGFloat] = []
        func flush() {
            addSmooth(points, bases: bases, to: body)
            addSmooth(points, bases: highlightBases, to: highlight)
            points.removeAll()
            bases.removeAll()
            highlightBases.removeAll()
        }
        for i in pile.heights.indices {
            let x = pile.columnX(i) + Pile.binWidth / 2
            let base = top + pile.drop(i)
            let height = pile.displayHeight(i)
            let middle = CGPoint(x: x, y: base - height / 2)
            if isCovered(middle, byWindowsBefore: index) || (alsoHiddenBehindDock && isBehindDock(middle)) {
                flush()
            } else {
                points.append(CGPoint(x: x, y: base - height))
                bases.append(base)
                highlightBases.append(base - height * 0.35)
            }
        }
        flush()
    }

    /// Le dessus suit les colonnes en courbes douces ; le dessous suit la base, arrondie dans les coins.
    private func addSmooth(_ points: [CGPoint], bases: [CGFloat], to path: CGMutablePath) {
        guard points.count > 1, zip(points, bases).contains(where: { $0.y < $1 - 0.5 }) else { return }
        let half = Pile.binWidth / 2
        path.move(to: CGPoint(x: points[0].x - half, y: bases[0]))
        path.addLine(to: points[0])
        for i in 1..<points.count {
            let mid = CGPoint(x: (points[i - 1].x + points[i].x) / 2, y: (points[i - 1].y + points[i].y) / 2)
            path.addQuadCurve(to: mid, control: points[i - 1])
        }
        path.addLine(to: points[points.count - 1])
        path.addLine(to: CGPoint(x: points[points.count - 1].x + half, y: bases[bases.count - 1]))
        for i in stride(from: points.count - 1, through: 0, by: -1) {
            path.addLine(to: CGPoint(x: points[i].x, y: bases[i]))
        }
        path.closeSubpath()
    }
}
