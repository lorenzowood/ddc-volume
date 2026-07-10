import AppKit

class VolumeSliderView: NSView {

    var onVolumeChange: ((Int) -> Void)?
    var onMuteToggle: (() -> Void)?

    private let titleLabel    = NSTextField(labelWithString: "Monitor volume")
    private let slider        = NSSlider()
    private let speakerButton = NSButton()

    static let viewWidth:  CGFloat = 260
    static let viewHeight: CGFloat = 46

    // Every icon variant is composited onto this same fixed-size canvas with
    // its glyph pinned at x=0, so the speaker cone never shifts between
    // variants — NSButton would otherwise center images of differing width.
    private static let iconCanvasSize = NSSize(width: 40, height: 20)
    private static let symConfig = NSImage.SymbolConfiguration(
        pointSize: 15, weight: .regular
    )
    private static let markSymConfig = NSImage.SymbolConfiguration(
        pointSize: 10, weight: .bold
    )

    init() {
        super.init(frame: NSRect(x: 0, y: 0,
                                 width: Self.viewWidth, height: Self.viewHeight))
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Mirrors the system volume control: the speaker icon reflects actual
    /// output (wave count from level, or an × when muted) and doubles as the
    /// mute toggle; the slider dims while muted but stays draggable.
    func update(volume: Int, muted: Bool) {
        slider.intValue = Int32(max(0, min(100, volume)))
        slider.alphaValue = muted ? 0.4 : 1.0
        speakerButton.image = Self.speakerImage(volume: volume, muted: muted)
    }

    // MARK: - Private

    private func setup() {
        let w    = Self.viewWidth
        let hPad: CGFloat = 12

        // Title row
        titleLabel.frame = NSRect(x: hPad, y: 26, width: w - 2 * hPad, height: 16)
        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.textColor = .labelColor
        addSubview(titleLabel)

        // Speaker button — click toggles mute, matching the system volume
        // control's convention.
        speakerButton.frame = NSRect(
            x: hPad, y: 5,
            width: Self.iconCanvasSize.width, height: Self.iconCanvasSize.height
        )
        speakerButton.isBordered = false
        speakerButton.imagePosition = .imageOnly
        speakerButton.imageScaling = .scaleProportionallyDown
        speakerButton.contentTintColor = .labelColor
        speakerButton.setButtonType(.momentaryChange)
        speakerButton.target = self
        speakerButton.action = #selector(speakerClicked)
        addSubview(speakerButton)

        // Slider — spans from the speaker button to the right edge
        let sliderX = hPad + Self.iconCanvasSize.width + 8
        let sliderW = w - hPad - sliderX
        slider.frame = NSRect(x: sliderX, y: 6, width: sliderW, height: 18)
        slider.minValue = 0
        slider.maxValue = 100
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved)
        addSubview(slider)
    }

    // Thirds of the range: 0 only at zero, 3 waves from two-thirds up.
    private static func speakerImage(volume: Int, muted: Bool) -> NSImage {
        let glyph: NSImage
        if muted {
            glyph = mutedGlyph()
        } else {
            let name: String
            switch volume {
            case 0:       name = "speaker.fill"
            case 1...33:  name = "speaker.wave.1.fill"
            case 34...66: name = "speaker.wave.2.fill"
            default:      name = "speaker.wave.3.fill"
            }
            glyph = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(symConfig) ?? NSImage()
        }
        return leftAligned(glyph)
    }

    private static func leftAligned(_ glyph: NSImage) -> NSImage {
        let size = glyph.size
        let img = NSImage(size: iconCanvasSize, flipped: false) { _ in
            glyph.draw(at: NSPoint(x: 0, y: (iconCanvasSize.height - size.height) / 2),
                       from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        img.isTemplate = true
        return img
    }

    // Draw offset for the × in the muted glyph, positioned so its visible
    // stroke starts at the same gap after the cone as the first wave arc in
    // speaker.wave.1.fill. Symbols' reported `.size` bounding boxes include
    // differing internal padding per glyph, so this can't be derived by
    // simply subtracting sizes — it was measured directly from rendered
    // pixels (a per-column alpha scan of both glyphs at high resolution).
    private static let muteMarkOffsetX: CGFloat = 12.4

    // Plain speaker cone (same glyph as the zero-volume icon) with a small ×
    // drawn to its right, rather than a crossed-out speaker.
    private static func mutedGlyph() -> NSImage {
        let cone = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(symConfig) ?? NSImage()
        let mark = NSImage(systemSymbolName: "multiply", accessibilityDescription: nil)?
            .withSymbolConfiguration(markSymConfig) ?? NSImage()
        let coneSize = cone.size
        let markSize = mark.size
        let height = max(coneSize.height, markSize.height)
        let width  = muteMarkOffsetX + markSize.width

        return NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            cone.draw(at: NSPoint(x: 0, y: (height - coneSize.height) / 2),
                      from: .zero, operation: .sourceOver, fraction: 1)
            mark.draw(at: NSPoint(x: muteMarkOffsetX, y: (height - markSize.height) / 2),
                      from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
    }

    @objc private func sliderMoved() {
        onVolumeChange?(Int(slider.intValue))
    }

    @objc private func speakerClicked() {
        onMuteToggle?()
    }
}
