import Foundation

public class VolumeState {
    private let queue = DispatchQueue(label: "ddc-volume.state")

    private var _desired: Int
    private var _lastSent: Int?
    private var _muted: Bool = false
    /// Bumped on every user command and every write, so an asynchronous monitor
    /// read can tell whether anything changed while it was in flight.
    private var _generation = 0
    /// True while an absolute `.set` is waiting to be sent (as opposed to relative up/down steps).
    private var _absolute = false

    public var onChange: (() -> Void)?

    public init(defaultVolume: Int) {
        _desired = max(0, min(100, defaultVolume))
    }

    // MARK: - Thread-safe reads

    public var desired: Int { queue.sync { _desired } }
    public var lastSent: Int? { queue.sync { _lastSent } }
    public var isMuted: Bool { queue.sync { _muted } }
    public var generation: Int { queue.sync { _generation } }

    // MARK: - Setup

    /// Forces the next timer tick to resync (used when switching monitors).
    public func resetSync() {
        queue.sync { _lastSent = nil }
    }

    /// Called after successfully reading the monitor's current volume on startup.
    /// Sets both desired and lastSent so no immediate sync is issued.
    public func initializeFromMonitor(_ volume: Int) {
        queue.sync {
            _desired = clamp(volume)
            _lastSent = _desired
        }
        scheduleChange()
    }

    // MARK: - Command handling

    public func apply(_ command: Command) -> StatusResponse {
        let response: StatusResponse = queue.sync {
            if case .get = command {} else { _generation += 1 }
            switch command {
            case .up(let n):
                _desired = clamp(_desired + n)
            case .down(let n):
                _desired = clamp(_desired - n)
            case .set(let n):
                _desired = clamp(n)
                _absolute = true
            case .mute:
                _muted = true
            case .unmute:
                _muted = false
            case .toggleMute:
                _muted = !_muted
            case .get:
                break
            }
            return snapshot()
        }
        scheduleChange()
        return response
    }

    // MARK: - Sync

    public struct SyncWork {
        public let volume: Int?
    }

    public func syncNeeded() -> SyncWork {
        queue.sync {
            let effective = _muted ? 0 : _desired
            let v: Int? = (_lastSent == nil || _lastSent! != effective) ? effective : nil
            return SyncWork(volume: v)
        }
    }

    public func markSent(volume: Int) {
        queue.sync {
            _lastSent = volume
            _generation += 1
            if volume == (_muted ? 0 : _desired) { _absolute = false }
        }
        scheduleChange()
    }

    /// Folds in a volume read back from the monitor, which is the source of truth.
    ///
    /// `generation` is the value of `generation` taken *before* the read began; if a
    /// command or write has happened since, the reading may be stale and is dropped.
    /// - No change pending: adopt the monitor's value (and unmute, since it moved).
    /// - Relative steps pending: re-base them onto the monitor's value, so a click
    ///   after an outside change steps from the real level rather than undoing it.
    /// - Absolute set or mute pending: keep the user's intent and just record what the
    ///   monitor really has, so the timer sends the correction.
    /// Returns true if anything visible changed.
    @discardableResult
    public func reconcile(monitorVolume: Int, generation: Int) -> Bool {
        let changed: Bool = queue.sync {
            guard generation == _generation else { return false }
            let v = clamp(monitorVolume)
            guard let expected = _lastSent, v != expected else { return false }
            let pending = (_muted ? 0 : _desired) != expected
            if !pending {
                _desired = v
                _muted = false
            } else if !_muted && !_absolute {
                _desired = clamp(v + (_desired - expected))
            }
            _lastSent = v
            return true
        }
        if changed { scheduleChange() }
        return changed
    }

    // MARK: - Private

    private func snapshot() -> StatusResponse {
        StatusResponse(desiredVolume: _desired, lastSentVolume: _lastSent, isMuted: _muted)
    }

    private func scheduleChange() {
        DispatchQueue.main.async { [weak self] in self?.onChange?() }
    }

    private func clamp(_ v: Int) -> Int { max(0, min(100, v)) }
}
