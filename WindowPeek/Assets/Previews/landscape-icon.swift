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
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
        let shape = NSBezierPath(roundedRect: r, xRadius: 32, yRadius: 32)
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
            NSBezierPath(ovalIn: CGRect(x: r.minX + 25 + CGFloat(i) * 20, y: r.maxY - 35, width: 10, height: 10)).fill()
        }
        ink.withAlphaComponent(0.20).setFill()
        NSBezierPath(rect: CGRect(x: r.minX + 2, y: r.maxY - 53, width: r.width - 4, height: 2)).fill()
        let label = number as NSString
        if !selected {
            label.draw(at: CGPoint(x: r.maxX - 48, y: r.maxY - 46), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .semibold),
                .foregroundColor: ink
            ])
        }
        if selected {
            let numeral = "2" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 185, weight: .semibold), .foregroundColor: ink]
            let size = numeral.size(withAttributes: attrs)
            numeral.draw(at: CGPoint(x: r.midX - size.width / 2, y: r.midY - size.height / 2 - 12), withAttributes: attrs)
        } else {
            ink.withAlphaComponent(0.16).setFill()
            for row in 0..<3 {
                NSBezierPath(roundedRect: CGRect(x: r.minX + 28, y: r.maxY - 100 - CGFloat(row) * 37, width: r.width * (row == 0 ? 0.55 : 0.72), height: 12), xRadius: 6, yRadius: 6).fill()
            }
        }
    }
    window(CGRect(x: 126, y: 542, width: 592, height: 306), number: "1", selected: false)
    window(CGRect(x: 306, y: 164, width: 592, height: 306), number: "3", selected: false)
    window(CGRect(x: 182, y: 320, width: 660, height: 380), number: "2", selected: true)
    return true
}

for pixels in [1024, 512] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("windowpeek-landscape-\(pixels).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
