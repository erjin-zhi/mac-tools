import AppKit

enum DemoImage {
    static func make(index: Int) -> NSImage {
        let size = NSSize(width: 720, height: 450)
        return NSImage(size: size, flipped: false) { rect in
            NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
            NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
            NSBezierPath(rect: CGRect(x: 0, y: 416, width: 720, height: 34)).fill()
            for (offset, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                color.setFill(); NSBezierPath(ovalIn: CGRect(x: 14 + offset * 21, y: 428, width: 11, height: 11)).fill()
            }
            let accents: [NSColor] = [.systemMint, .systemBlue, .systemOrange, .systemGreen]
            let accent = accents[index % accents.count]
            if index == 0 {
                NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
                NSBezierPath(rect: CGRect(x: 0, y: 0, width: 145, height: 415)).fill()
                for row in 0..<6 { bar(CGRect(x: 22, y: 350 - row * 42, width: 95, height: 10), color: row == 0 ? accent : .darkGray) }
                for column in 0..<3 {
                    bar(CGRect(x: 175 + column * 170, y: 255, width: 145, height: 102), color: accent.withAlphaComponent(0.22))
                    bar(CGRect(x: 190 + column * 170, y: 315, width: 60, height: 14), color: accent)
                }
                for row in 0..<4 { bar(CGRect(x: 175, y: 195 - row * 40, width: 490 - row * 25, height: 13), color: .darkGray) }
            } else if index == 1 {
                for column in 0..<3 {
                    bar(CGRect(x: 40 + column * 225, y: 110, width: 195, height: 220), color: accent.withAlphaComponent(0.14))
                    bar(CGRect(x: 55 + column * 225, y: 200, width: 165, height: 110), color: accent.withAlphaComponent(0.5))
                    bar(CGRect(x: 55 + column * 225, y: 160, width: 120, height: 12), color: .lightGray)
                }
            } else {
                for row in 0..<11 {
                    bar(CGRect(x: 38 + (row % 3) * 20, y: 373 - row * 29, width: 180 + (row * 73 % 400), height: row == 0 ? 16 : 9), color: row % 3 == 0 ? accent : .darkGray)
                }
            }
            return true
        }
    }
    static func bar(_ rect: CGRect, color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
    }
}
