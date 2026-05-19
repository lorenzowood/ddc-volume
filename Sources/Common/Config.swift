import Foundation

public struct Config: Codable {
    public let monitorId: String
    public let m1ddcPath: String
    public let minIntervalMs: Int
    public let readVolumeOnStartup: Bool
    public let defaultVolume: Int

    public init(
        monitorId: String,
        m1ddcPath: String = "/opt/homebrew/bin/m1ddc",
        minIntervalMs: Int = 500,
        readVolumeOnStartup: Bool = true,
        defaultVolume: Int = 60
    ) {
        self.monitorId = monitorId
        self.m1ddcPath = m1ddcPath
        self.minIntervalMs = minIntervalMs
        self.readVolumeOnStartup = readVolumeOnStartup
        self.defaultVolume = max(0, min(100, defaultVolume))
    }

    public static var configFilePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ddc-volume/config.json").path
    }

    public static var socketPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ddc-volume/daemon.sock").path
    }

    public static func load(from path: String? = nil) throws -> Config {
        let filePath = path ?? configFilePath
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let decoder = JSONDecoder()
        return try decoder.decode(Config.self, from: data)
    }
}

public enum ConfigError: Error, LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "Config file not found: \(path)"
        case .decodingFailed(let detail): return "Config decoding failed: \(detail)"
        }
    }
}
