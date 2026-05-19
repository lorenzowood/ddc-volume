import AppKit

class VolumeSliderView: NSView {

    var onVolumeChange: ((Int) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Monitor volume")
    private let slider     = NSSlider()
    private let lowIcon    = NSImageView()
    private let highIcon   = NSImageView()

    static let viewWidth:  CGFloat = 260
    static let viewHeight: CGFloat = 46

    // Pinned point size so both icons render at the same cap height
    // regardless of their differing aspect ratios.
    private static let symConfig = NSImage.SymbolConfiguration(
        pointSize: 11, weight: .regular
    )

    init() {
        super.init(frame: NSRect(x: 0, y: 0,
                                 width: Self.viewWidth, height: Self.viewHeight))
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setVolume(_ volume: Int) {
        slider.intValue = Int32(max(0, min(100, volume)))
    }

    // MARK: - Private

    private func setup() {
        let w    = Self.viewWidth
        let hPad: CGFloat = 12
        let iconH: CGFloat = 14

        // Title row
        titleLabel.frame = NSRect(x: hPad, y: 26, width: w - 2 * hPad, height: 16)
        titleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.textColor = .labelColor
        addSubview(titleLabel)

        // Low-volume icon — speaker.fill is roughly square, 14pt frame is fine
        lowIcon.frame = NSRect(x: hPad, y: 7, width: iconH, height: iconH)
        lowIcon.image = NSImage(systemSymbolName: "speaker.fill",
                                accessibilityDescription: nil)
        lowIcon.symbolConfiguration = Self.symConfig
        lowIcon.contentTintColor = .secondaryLabelColor
        lowIcon.imageScaling = .scaleProportionallyDown
        addSubview(lowIcon)

        // High-volume icon — speaker.wave.3.fill is much wider than tall;
        // give it a 26 × 14 frame so it fits at full height without squishing.
        let highIconW: CGFloat = 26
        let highIconX = w - hPad - highIconW
        highIcon.frame = NSRect(x: highIconX, y: 7, width: highIconW, height: iconH)
        highIcon.image = NSImage(systemSymbolName: "speaker.wave.3.fill",
                                  accessibilityDescription: nil)
        highIcon.symbolConfiguration = Self.symConfig
        highIcon.contentTintColor = .secondaryLabelColor
        highIcon.imageScaling = .scaleProportionallyDown
        addSubview(highIcon)

        // Slider — spans between the two icons
        let sliderX = hPad + iconH + 4
        let sliderW = highIconX - 4 - sliderX
        slider.frame = NSRect(x: sliderX, y: 6, width: sliderW, height: 18)
        slider.minValue = 0
        slider.maxValue = 100
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved)
        addSubview(slider)
    }

    @objc private func sliderMoved() {
        onVolumeChange?(Int(slider.intValue))
    }
}
