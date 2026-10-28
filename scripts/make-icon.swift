// Dessine l'icône de Flocon : ciel de nuit, flocon blanc, neige posée en bas.
import AppKit

let output = CommandLine.arguments[1]
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(red: 0.25, green: 0.45, blue: 0.85, alpha: 1),
           ending: NSColor(red: 0.06, green: 0.12, blue: 0.32, alpha: 1))!.draw(in: shape, angle: -90)

shape.addClip()
let snow = NSBezierPath()
snow.move(to: NSPoint(x: tile.minX, y: tile.minY))
snow.line(to: NSPoint(x: tile.minX, y: 300))
snow.curve(to: NSPoint(x: 512, y: 330), controlPoint1: NSPoint(x: 260, y: 360), controlPoint2: NSPoint(x: 380, y: 300))
snow.curve(to: NSPoint(x: tile.maxX, y: 290), controlPoint1: NSPoint(x: 660, y: 360), controlPoint2: NSPoint(x: 800, y: 340))
snow.line(to: NSPoint(x: tile.maxX, y: tile.minY))
snow.close()
NSColor(red: 0.88, green: 0.93, blue: 1, alpha: 1).setFill()
snow.fill()
NSColor.white.setFill()

let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
if let flake = NSImage(systemSymbolName: "snowflake", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let s = flake.size
    flake.draw(in: NSRect(x: 512 - s.width / 2, y: 600 - s.height / 2, width: s.width, height: s.height))
}
for (x, y, r) in [(260.0, 780.0, 14.0), (760.0, 720.0, 18.0), (330.0, 520.0, 10.0), (720.0, 470.0, 12.0)] {
    NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
