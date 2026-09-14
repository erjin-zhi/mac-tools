import AppKit

/// Three numbered cards: deliberately no monitor silhouette, stand, or sharing arrow.
enum IconArtwork {
    static func menuImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 24, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            for x: CGFloat in [1, 18] {
                let side = NSBezierPath(roundedRect: CGRect(x: x, y: 4, width: 5, height: 10), xRadius: 1.5, yRadius: 1.5)
                side.lineWidth = 1.25
                side.stroke()
            }
            NSColor.black.setFill()
            NSBezierPath(roundedRect: CGRect(x: 7, y: 1, width: 10, height: 16), xRadius: 2.5, yRadius: 2.5).fill()
            // Knock the 2 out of the template so it stays legible on light and dark menu bars.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            let text = "2" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
                .foregroundColor: NSColor.black
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: 12 - size.width / 2, y: 9 - size.height / 2), withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Window Peek，编号窗口切换"
        return image
    }

    static func appImage(size: CGFloat = 1024) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.scale(by: size / 1024)
            transform.concat()
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
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
    }
}
