import Foundation

public class MonitorController {
    private let config: Config
    public var activeMonitorId: String

    public struct MonitorInfo: Equatable {
        public let id: String
        public let name: String
        public init(id: String, name: String) { self.id = id; self.name = name }
    }

    public init(config: Config) {
        self.config = config
        self.activeMonitorId = config.monitorId
    }

    public func getCurrentVolume() throws -> Int {
        let output = try run("display", activeMonitorId, "get", "volume")
        guard let volume = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw MonitorError.unexpectedOutput(output)
        }
        return max(0, min(100, volume))
    }

    public func setVolume(_ volume: Int) throws {
        _ = try run("display", activeMonitorId, "set", "volume", "\(volume)")
    }

    public func listMonitors() throws -> [MonitorInfo] {
        let output = try run("display", "list")
        return Self.parseMonitorList(output)
    }

    // Parses lines of the form: [N] PRODUCT NAME (UUID)
    static func parseMonitorList(_ raw: String) -> [MonitorInfo] {
        raw.components(separatedBy: .newlines).compactMap { line in
            let s = line.trimmingCharacters(in: .whitespaces)
            guard s.hasPrefix("["),
                  let closeBracket  = s.firstIndex(of: "]"),
                  let openParen     = s.lastIndex(of: "("),
                  let closeParen    = s.lastIndex(of: ")"),
                  openParen < closeParen,
                  let nameStart = s.index(closeBracket, offsetBy: 2, limitedBy: s.endIndex)
            else { return nil }

            let name = String(s[nameStart..<openParen]).trimmingCharacters(in: .whitespaces)
            let id   = String(s[s.index(after: openParen)..<closeParen]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !id.isEmpty else { return nil }
            return MonitorInfo(id: id, name: name)
        }
    }

    // MARK: - Private

    @discardableResult
    private func run(_ args: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.m1ddcPath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw MonitorError.commandFailed(args.joined(separator: " "), output)
        }
        return output
    }
}

public enum MonitorError: Error, LocalizedError {
    case commandFailed(String, String)
    case unexpectedOutput(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let cmd, let output):
            return "m1ddc '\(cmd)' failed: \(output)"
        case .unexpectedOutput(let output):
            return "unexpected m1ddc output: \(output)"
        }
    }
}
