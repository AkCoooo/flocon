import CoreGraphics

/// Tas de neige posé sur un bord horizontal, découpé en colonnes.
/// Le bord peut avoir des coins arrondis : la base du tas suit la courbe,
/// et là où la pente dépasse 45°, la neige ne tient pas et glisse.
final class Pile {
    static let binWidth: CGFloat = 3
    let originX: CGFloat
    let maxHeight: CGFloat
    private(set) var heights: [CGFloat]
    /// Bosses propres à chaque tas, pour qu'aucun ne soit une règle parfaite.
    private let bumps: [CGFloat]
    /// Descente de la base sous le bord, dans les coins arrondis.
    private let drops: [CGFloat]
    /// Part de neige que la pente laisse tenir, de 0 (glisse) à 1 (plat).
    private let grip: [CGFloat]

    init(minX: CGFloat, width: CGFloat, maxHeight: CGFloat, cornerRadius: CGFloat = 0) {
        originX = minX
        self.maxHeight = maxHeight
        let count = max(1, Int(ceil(width / Pile.binWidth)))
        heights = Array(repeating: 0, count: count)

        let phases = (0..<3).map { _ in CGFloat.random(in: 0...(2 * .pi)) }
        bumps = (0..<count).map { i in
            let x = CGFloat(i)
            let wave = sin(x / 9 + phases[0]) + 0.6 * sin(x / 4.3 + phases[1]) + 0.3 * sin(x / 2.1 + phases[2])
            return 0.9 + 0.08 * wave
        }

        let r = min(cornerRadius, width / 2)
        var drops: [CGFloat] = []
        var grip: [CGFloat] = []
        for i in 0..<count {
            let center = (CGFloat(i) + 0.5) * Pile.binWidth
            let fromEdge = min(center, width - center)
            guard r > 0, fromEdge < r else {
                drops.append(0)
                grip.append(r > 0 ? 1 : Self.flatEdgeGrip(fromEdge: fromEdge))
                continue
            }
            let dx = r - fromEdge
            let dy = sqrt(max(r * r - dx * dx, 0.01))
            drops.append(r - dy)
            let slope = dx / dy
            grip.append(max(0, 1 - slope))
        }
        self.drops = drops
        self.grip = grip
    }

    /// Sans coin arrondi, le tas s'arrondit quand même au bord, en quart de cercle.
    private static func flatEdgeGrip(fromEdge: CGFloat) -> CGFloat {
        let t = min(1, (fromEdge / binWidth + 0.5) / 10)
        return sqrt(1 - (1 - t) * (1 - t))
    }

    var maxX: CGFloat { originX + CGFloat(heights.count) * Pile.binWidth }

    func contains(x: CGFloat) -> Bool { x >= originX && x < maxX }

    func index(atX x: CGFloat) -> Int {
        min(max(Int((x - originX) / Pile.binWidth), 0), heights.count - 1)
    }

    func canHold(atX x: CGFloat) -> Bool { grip[index(atX: x)] > 0.15 }

    /// Hauteur du dessus de la neige au-dessus du bord droit, en tenant compte du coin.
    func surfaceOffset(atX x: CGFloat) -> CGFloat {
        let i = index(atX: x)
        return drops[i] - displayHeight(i)
    }

    func height(atX x: CGFloat) -> CGFloat { displayHeight(index(atX: x)) }

    func drop(_ i: Int) -> CGFloat { drops[i] }

    func displayHeight(_ i: Int) -> CGFloat { heights[i] * bumps[i] }

    func columnX(_ i: Int) -> CGFloat { originX + CGFloat(i) * Pile.binWidth }

    private func capacity(_ i: Int) -> CGFloat { maxHeight * grip[i] }

    private static let spread: [(offset: Int, weight: CGFloat)] = [
        (0, 0.36), (-1, 0.2), (1, 0.2), (-2, 0.08), (2, 0.08), (-3, 0.04), (3, 0.04),
    ]

    func add(atX x: CGFloat, amount: CGFloat) {
        var i = index(atX: x)
        // Un flocon roule vers le voisin plus bas, comme du sable.
        for _ in 0..<4 {
            let left = i > 0 ? heights[i - 1] : .infinity
            let right = i < heights.count - 1 ? heights[i + 1] : .infinity
            let lowest = min(left, right)
            guard lowest < heights[i] - amount else { break }
            i = left <= right ? i - 1 : i + 1
        }
        for (offset, weight) in Pile.spread {
            let j = i + offset
            guard heights.indices.contains(j) else { continue }
            heights[j] = min(heights[j] + amount * weight, capacity(j))
        }
    }
}
