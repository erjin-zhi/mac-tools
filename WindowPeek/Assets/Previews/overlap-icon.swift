import AppKit

// Design preview only. Not included in the app target or build script.
let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
    let base = NSBezierPath(roundedRect: CGRect(x: 62, y: 62, width: 900, height: 900), xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.27, alpha: 1),
               ending: NSColor(calibratedRed: 0.025, green: 0.06, blue: 0.085, alpha: 1))!.draw(in: base, angle: -75)
    NSColor.white.withAlphaComponent(0.14).setStroke()
    base.lineWidth = 2
    base.stroke()

    func window(_ r: CGRect, number: String, selected: Bool) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.36)
        shadow.shadowBlurRadius = selected ? 36 : 18
        shadow.shadowOffset = NSSize(width: 0, height: selected ? -16 : -8)
        shadow.set()
        let shape = NSBezierPath(roundedRect: r, xRadius: selected ? 34 : 26, yRadius: selected ? 34 : 26)
        let light = NSColor(calibratedRed: 0.47, green: 1.0, blue: 0.86, alpha: 1)
        let dark = NSColor(calibratedRed: 0.08, green: 0.73, blue: 0.65, alpha: 1)
        let muted = NSColor(calibratedRed: 0.22, green: 0.34, blue: 0.39, alpha: 1)
        NSGradient(starting: selected ? light : muted,
                   ending: selected ? dark : NSColor(calibratedRed: 0.13, green: 0.23, blue: 0.28, alpha: 1))!.draw(in: shape, angle: -90)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(selected ? 0.5 : 0.22).setStroke()
        shape.lineWidth = 2
        shape.stroke()
        let ink = selected ? NSColor(calibratedRed: 0.035, green: 0.24, blue: 0.24, alpha: 1) : NSColor.white.withAlphaComponent(0.65)
        ink.withAlphaComponent(selected ? 0.45 : 0.5).setFill()
        for i in 0..<3 {
            NSBezierPath(ovalIn: CGRect(x: r.minX + 22 + CGFloat(i) * 17, y: r.maxY - 29, width: 8, height: 8)).fill()
        }
        ink.withAlphaComponent(0.20).setFill()
        NSBezierPath(rect: CGRect(x: r.minX + 2, y: r.maxY - 45, width: r.width - 4, height: 2)).fill()
        let numeral = number as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: selected ? 194 : 112, weight: .semibold), .foregroundColor: ink]
        let size = numeral.size(withAttributes: attrs)
        let centerX: CGFloat = selected ? r.midX : (number == "1" ? 185 : 839)
        numeral.draw(at: CGPoint(x: centerX - size.width / 2, y: r.midY - size.height / 2 - 15), withAttributes: attrs)
    }
    window(CGRect(x: 100, y: 375, width: 392, height: 274), number: "1", selected: false)
    window(CGRect(x: 532, y: 375, width: 392, height: 274), number: "3", selected: false)
    window(CGRect(x: 268, y: 336, width: 488, height: 352), number: "2", selected: true)
    NSColor(calibratedRed: 0.35, green: 0.97, blue: 0.81, alpha: 1).setFill()
    NSBezierPath(roundedRect: CGRect(x: 476, y: 273, width: 72, height: 11), xRadius: 5.5, yRadius: 5.5).fill()
    return true
}

for pixels in [1024, 512] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("windowpeek-overlap-\(pixels).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
