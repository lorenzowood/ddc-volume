import AppKit

enum MenuBarImage {
    static let size = NSSize(width: 54, height: 18)

    private static let barHeight: CGFloat = 12
    private static let barMargin: CGFloat = 2

    static func make(volume: Int, isMuted: Bool) -> NSImage {
        let img = NSImage(size: size, flipped: false) { _ in
            let alpha: CGFloat = isMuted ? 0.3 : 1.0
            drawBar(volume: volume, alpha: alpha)
            if isMuted { drawMuteLine() }
            return true
        }
        img.isTemplate = true
        return img
    }

    private static func drawBar(volume: Int, alpha: CGFloat) {
        let barY = (size.height - barHeight) / 2
        let outerRect = NSRect(x: 0, y: barY, width: size.width, height: barHeight)

        NSColor.black.withAlphaComponent(alpha).setStroke()
        let outer = NSBezierPath(rect: outerRect)
        outer.lineWidth = 1.2
        outer.stroke()

        let innerMaxWidth = size.width - 2 * barMargin
        let fill = innerMaxWidth * CGFloat(max(0, min(100, volume))) / 100
        if fill > 0 {
            NSColor.black.withAlphaComponent(alpha).setFill()
            NSBezierPath(rect: NSRect(
                x: barMargin,
                y: barY + barMargin,
                width: fill,
                height: barHeight - 2 * barMargin
            )).fill()
        }
    }

    private static func drawMuteLine() {
        let barY = (size.height - barHeight) / 2
        NSColor.black.setStroke()
        let line = NSBezierPath()
        line.move(to:  NSPoint(x: 0,          y: barY))
        line.line(to:  NSPoint(x: size.width, y: barY + barHeight))
        line.lineWidth = 1.5
        line.stroke()
    }
}
