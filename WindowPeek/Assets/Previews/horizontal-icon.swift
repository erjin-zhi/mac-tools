import AppKit

// Design preview only. Not included in the app target or build script.
let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
    let base = NSBezierPath(roundedRect: CGRect(x: 62, y: 62, width: 900, height: 900), xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.27, alpha: 1),
               ending: NSColor(calibratedRed: 0.025, green: 0.06, blue: 0.085, alpha: 1))!.draw(in: base, angle: -75)
    NSColor.white.withAlphaComponent(0.14).setStroke()
    base.lineWidth = 2
    base.stroke()

    let tray = NSBezierPath(roundedRect: CGRect(x: 84, y: 337, width: 856, height: 350), xRadius: 52, yRadius: 52)
    NSColor.white.withAlphaComponent(0.055).setFill()
    tray.fill()
    NSColor.white.withAlphaComponent(0.09).setStroke()
    tray.lineWidth = 2
    tray.stroke()

    func window(_ r: CGRect, number: String, selected: Bool) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.36)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
        let shape = NSBezierPath(roundedRect: r, xRadius: 20, yRadius: 20)
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
            NSBezierPath(ovalIn: CGRect(x: r.minX + 16 + CGFloat(i) * 13, y: r.maxY - 22, width: 6, height: 6)).fill()
        }
        ink.withAlphaComponent(0.20).setFill()
        NSBezierPath(rect: CGRect(x: r.minX + 2, y: r.maxY - 34, width: r.width - 4, height: 2)).fill()
        let numeral = number as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: selected ? 118 : 90, weight: .semibold), .foregroundColor: ink]
        let size = numeral.size(withAttributes: attrs)
        numeral.draw(at: CGPoint(x: r.midX - size.width / 2, y: r.midY - size.height / 2 - 12), withAttributes: attrs)
    }
    window(CGRect(x: 108, y: 430, width: 240, height: 164), number: "1", selected: false)
    window(CGRect(x: 676, y: 430, width: 240, height: 164), number: "3", selected: false)
    window(CGRect(x: 366, y: 412, width: 292, height: 200), number: "2", selected: true)
    NSColor(calibratedRed: 0.35, green: 0.97, blue: 0.81, alpha: 1).setFill()
    NSBezierPath(roundedRect: CGRect(x: 481, y: 365, width: 62, height: 9), xRadius: 4.5, yRadius: 4.5).fill()
    return true
}

for pixels in [1024, 512] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("windowpeek-horizontal-\(pixels).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
