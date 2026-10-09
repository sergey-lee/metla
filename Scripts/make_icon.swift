// Builds AppIcon.iconset from Resources/Logo.png: the artwork on a light rounded tile with the
// macOS icon grid (824 pt tile on a 1024 pt canvas) and a soft shadow.
// usage: swift Scripts/make_icon.swift <logo.png> <output.iconset>
import AppKit

let logo = NSImage(contentsOf: URL(filePath: CommandLine.arguments[1]))!
let output = URL(filePath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// Bounds of the visible artwork inside the logo, so transparent margins do not shrink it.
func contentBounds(_ image: NSImage) -> NSRect {
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let w = rep.pixelsWide, h = rep.pixelsHigh
    var minX = w, minY = h, maxX = 0, maxY = 0
    for y in stride(from: 0, to: h, by: 2) {
        for x in stride(from: 0, to: w, by: 2) where rep.colorAt(x: x, y: y)!.alphaComponent > 0.05 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    let scale = image.size.width / Double(w)
    // Bitmap rows go top-down, image coordinates bottom-up.
    return NSRect(x: Double(minX) * scale, y: Double(h - maxY) * scale,
                  width: Double(maxX - minX) * scale, height: Double(maxY - minY) * scale)
}
let art = contentBounds(logo)

func render(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context

    let unit = Double(pixels) / 1024
    let tile = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185 * unit, yRadius: 185 * unit)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 18 * unit
    shadow.shadowOffset = NSSize(width: 0, height: -8 * unit)
    shadow.set()
    NSColor.white.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(red: 1, green: 1, blue: 1, alpha: 1),
        NSColor(red: 0.91, green: 0.95, blue: 1, alpha: 1)
    ])!.draw(in: shape, angle: -90)
    NSColor.black.withAlphaComponent(0.06).setStroke()
    shape.lineWidth = max(1, 2 * unit)
    shape.stroke()

    // The artwork fills about three quarters of the tile, centred.
    let side = 640 * unit
    let fit = min(side / art.width, side / art.height)
    let size = NSSize(width: art.width * fit, height: art.height * fit)
    let target = NSRect(x: tile.midX - size.width / 2, y: tile.midY - size.height / 2, width: size.width, height: size.height)
    shape.addClip()
    logo.draw(in: target, from: art, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: output.appending(path: "icon_\(points)x\(points).png"))
    try render(points * 2).write(to: output.appending(path: "icon_\(points)x\(points)@2x.png"))
}
