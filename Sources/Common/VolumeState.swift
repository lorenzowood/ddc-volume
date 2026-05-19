import Foundation

public class VolumeState {
    private let queue = DispatchQueue(label: "ddc-volume.state")

    private var _desired: Int
    private var _lastSent: Int?
    private var _muted: Bool = false

    public var onChange: (() -> Void)?

    public init(defaultVolume: Int) {
        _desired = max(0, min(100, defaultVolume))
    }

    // MARK: - Thread-safe reads

    public var desired: Int { queue.sync { _desired } }
    public var lastSent: Int? { queue.sync { _lastSent } }
    public var isMuted: Bool { queue.sync { _muted } }

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
            switch command {
            case .up(let n):
                _desired = clamp(_desired + n)
            case .down(let n):
                _desired = clamp(_desired - n)
            case .set(let n):
                _desired = clamp(n)
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
        queue.sync { _lastSent = volume }
        scheduleChange()
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
