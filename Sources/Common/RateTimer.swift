import Foundation

public class RateTimer {
    private let intervalMs: Int
    private var source: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "ddc-volume.timer", qos: .utility)

    public var onTick: (() -> Void)?

    public init(intervalMs: Int) {
        self.intervalMs = intervalMs
    }

    public func start() {
        let src = DispatchSource.makeTimerSource(queue: queue)
        src.schedule(
            deadline: .now() + .milliseconds(intervalMs),
            repeating: .milliseconds(intervalMs),
            leeway: .milliseconds(50)
        )
        src.setEventHandler { [weak self] in self?.onTick?() }
        src.resume()
        source = src
    }

    public func stop() {
        source?.cancel()
        source = nil
    }
}
