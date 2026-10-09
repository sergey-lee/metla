// Frames a window capture for the Mac App Store: gradient backdrop, headline, subtitle, window with shadow.
// usage: compose_store_shot <window.png> <out.png> <headline> <subtitle>
import AppKit

let args = CommandLine.arguments
let window = NSImage(contentsOf: URL(filePath: args[1]))!
let width = 2880.0, height = 1800.0
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(colors: [
    NSColor(red: 0.07, green: 0.35, blue: 0.42, alpha: 1),
    NSColor(red: 0.06, green: 0.16, blue: 0.38, alpha: 1)
])!.draw(in: canvas, angle: -60)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
func draw(_ text: String, size: Double, weight: NSFont.Weight, alpha: Double, top: Double) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        .paragraphStyle: paragraph
    ]
    let rect = NSRect(x: 120, y: height - top - size * 1.35, width: width - 240, height: size * 1.4)
    NSAttributedString(string: text, attributes: attributes).draw(in: rect)
}
draw(args[3], size: 104, weight: .bold, alpha: 1, top: 92)
draw(args[4], size: 50, weight: .regular, alpha: 0.82, top: 250)

let maxWidth = 2400.0, maxHeight = height - 400 - 70
let scale = min(maxWidth / window.size.width, maxHeight / window.size.height)
let size = NSSize(width: window.size.width * scale, height: window.size.height * scale)
let frame = NSRect(x: (width - size.width) / 2, y: 70, width: size.width, height: size.height)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
shadow.shadowBlurRadius = 60
shadow.shadowOffset = NSSize(width: 0, height: -20)
shadow.set()
window.draw(in: frame)

NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(filePath: args[2]))
