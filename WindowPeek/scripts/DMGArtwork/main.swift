import AppKit

// Finder uses a 720 × 460 point canvas; render at 2× for Retina displays.
let width = 720
let height = 460
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 2,
    pixelsHigh: height * 2, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: width, height: height)
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.translateBy(x: 0, y: CGFloat(height))
context.cgContext.scaleBy(x: 1, y: -1)

func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func rounded(_ rect: NSRect, _ radius: CGFloat, _ hex: Int) {
    color(hex).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat,
          size: CGFloat, weight: NSFont.Weight = .regular, hex: Int = 0x263C36) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color(hex), .paragraphStyle: paragraph
    ]
    NSGraphicsContext.saveGraphicsState()
    // AppKit text needs a flipped graphics context for top-down layout.
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    (value as NSString).draw(in: NSRect(x: x, y: y, width: width, height: size * 1.7),
                             withAttributes: attributes)
    NSGraphicsContext.restoreGraphicsState()
}
rounded(NSRect(x: 0, y: 0, width: width, height: height), 0, 0xFAF9F3)
rounded(NSRect(x: 276, y: 28, width: 168, height: 28), 14, 0xE2EDE5)
text("W I N D O W   P E E K", x: 276, y: 34, width: 168, size: 10, weight: .bold)
text("给窗口小帮手，安个家。", x: 50, y: 70, width: 620, size: 30, weight: .semibold)
text("拖过去，就住下啦", x: 210, y: 119, width: 300, size: 15, hex: 0x65766E)
rounded(NSRect(x: 94, y: 177, width: 172, height: 160), 30, 0xEFEDE3)
rounded(NSRect(x: 454, y: 177, width: 172, height: 160), 30, 0xE0EEE3)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 292, y: 253))
arrow.curve(to: NSPoint(x: 414, y: 238), controlPoint1: NSPoint(x: 338, y: 185),
            controlPoint2: NSPoint(x: 343, y: 290))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
color(0x50886A).setStroke()
arrow.stroke()
let tip = NSBezierPath()
tip.move(to: NSPoint(x: 395, y: 238))
tip.line(to: NSPoint(x: 416, y: 235))
tip.line(to: NSPoint(x: 412, y: 255))
tip.lineWidth = 4
tip.lineCapStyle = .round
tip.lineJoinStyle = .round
tip.stroke()
text("咻～", x: 325, y: 285, width: 70, size: 15, weight: .medium, hex: 0x50886A)
text("01  拎起我", x: 104, y: 350, width: 152, size: 13, weight: .medium)
text("02  放这里", x: 464, y: 350, width: 152, size: 13, weight: .medium)
text("拖入 Applications 后，从「应用程序」打开", x: 80, y: 400, width: 560,
     size: 13, hex: 0x65766E)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
