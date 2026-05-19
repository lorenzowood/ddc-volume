import AppKit
import Common

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var state: VolumeState!
    private var monitor: MonitorController!
    private var server: CommandServer!
    private var timer: RateTimer!
    private var config: Config!

    private let statusMenu   = NSMenu()
    private var sliderView   = VolumeSliderView()
    private var monitorMenuItemsIndex = 3  // items at this index and beyond are monitor rows

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            config = try Config.load()
        } catch {
            NSLog("[ddc-volume] Config error: \(error). Using defaults with empty monitorId.")
            config = Config(monitorId: "")
        }

        state = VolumeState(defaultVolume: config.defaultVolume)
        state.onChange = { [weak self] in
            guard let self = self else { return }
            self.updateStatusItem()
            self.sliderView.setVolume(self.state.desired)
        }

        monitor = MonitorController(config: config)

        setupStatusItem()
        setupMenu()
        startServer()
        startTimer()

        if config.readVolumeOnStartup {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                if let v = try? self.monitor.getCurrentVolume() {
                    self.state.initializeFromMonitor(v)
                }
            }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let vol   = state.desired
        let muted = state.isMuted
        button.image = MenuBarImage.make(volume: vol, isMuted: muted)
        button.image?.size = MenuBarImage.size
        button.imageScaling = .scaleProportionallyDown
    }

    // MARK: - Menu

    private func setupMenu() {
        statusMenu.delegate = self

        // Slider row
        sliderView.onVolumeChange = { [weak self] volume in
            _ = self?.state.apply(.set(volume))
        }
        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        statusMenu.addItem(sliderItem)

        // Separator
        statusMenu.addItem(.separator())

        // Section header — custom view gives full style control (bold, labelColor, no indent)
        let headerItem = NSMenuItem()
        headerItem.view = MenuSectionHeaderView(title: "Monitor")
        statusMenu.addItem(headerItem)

        monitorMenuItemsIndex = statusMenu.items.count

        // Attach menu to button
        statusItem?.menu = statusMenu
    }

    func menuWillOpen(_ menu: NSMenu) {
        sliderView.setVolume(state.desired)
        rebuildMonitorItems()
    }

    private func rebuildMonitorItems() {
        // Remove old monitor rows
        while statusMenu.items.count > monitorMenuItemsIndex {
            statusMenu.removeItem(at: monitorMenuItemsIndex)
        }

        let monitors = (try? monitor.listMonitors()) ?? []
        let active   = monitor.activeMonitorId

        for info in monitors {
            let item = NSMenuItem(
                title: info.name,
                action: #selector(selectMonitor(_:)),
                keyEquivalent: ""
            )
            item.representedObject = info.id
            item.state = (info.id == active) ? .on : .off
            item.target = self
            statusMenu.addItem(item)
        }

        // Fallback if list fails or is empty
        if monitors.isEmpty {
            let item = NSMenuItem(title: active.isEmpty ? "(no monitor)" : active,
                                  action: nil, keyEquivalent: "")
            item.state = .on
            item.isEnabled = false
            statusMenu.addItem(item)
        }
    }

    @objc private func selectMonitor(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        monitor.activeMonitorId = id

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let v = try? self.monitor.getCurrentVolume() {
                self.state.initializeFromMonitor(v)
            } else {
                self.state.resetSync()
            }
        }
    }

    // MARK: - Server

    private func startServer() {
        server = CommandServer(socketPath: Config.socketPath)
        server.onCommand = { [weak self] command -> StatusResponse in
            guard let self = self else {
                return StatusResponse(desiredVolume: 0, lastSentVolume: nil, isMuted: false)
            }
            return self.state.apply(command)
        }
        do {
            try server.start()
        } catch {
            NSLog("[ddc-volume] Server failed to start: \(error)")
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = RateTimer(intervalMs: config.minIntervalMs)
        timer.onTick = { [weak self] in self?.timerTick() }
        timer.start()
    }

    private func timerTick() {
        guard let v = state.syncNeeded().volume else { return }
        do {
            try monitor.setVolume(v)
            state.markSent(volume: v)
        } catch {
            NSLog("[ddc-volume] setVolume error: \(error)")
        }
    }
}

// Bold section header rendered as a custom view so it stays at full labelColor
// opacity regardless of NSMenuItem's isEnabled state.
private class MenuSectionHeaderView: NSView {
    init(title: String) {
        let w = VolumeSliderView.viewWidth
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: 24))
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 12, y: 4, width: w - 12, height: 16)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        label.textColor = .labelColor
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
}
