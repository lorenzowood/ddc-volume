import XCTest
@testable import Common

final class ConfigTests: XCTestCase {

    // MARK: - Decoding

    func testDecodeAllFields() throws {
        let json = """
        {
            "monitorId": "ABC-123",
            "m1ddcPath": "/usr/local/bin/m1ddc",
            "minIntervalMs": 300,
            "readVolumeOnStartup": false,
            "defaultVolume": 70
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(config.monitorId, "ABC-123")
        XCTAssertEqual(config.m1ddcPath, "/usr/local/bin/m1ddc")
        XCTAssertEqual(config.minIntervalMs, 300)
        XCTAssertFalse(config.readVolumeOnStartup)
        XCTAssertEqual(config.defaultVolume, 70)
    }

    func testDecodeMissingMonitorId() {
        let json = """
        {
            "m1ddcPath": "/opt/homebrew/bin/m1ddc",
            "minIntervalMs": 500,
            "readVolumeOnStartup": true,
            "defaultVolume": 60
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(Config.self, from: json))
    }

    func testDecodeOnlyRequired() throws {
        let json = """
        {
            "monitorId": "XYZ-789",
            "m1ddcPath": "/opt/homebrew/bin/m1ddc",
            "minIntervalMs": 500,
            "readVolumeOnStartup": true,
            "defaultVolume": 60
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(config.monitorId, "XYZ-789")
    }

    // MARK: - Init defaults

    func testInitDefaults() {
        let c = Config(monitorId: "test")
        XCTAssertEqual(c.m1ddcPath, "/opt/homebrew/bin/m1ddc")
        XCTAssertEqual(c.minIntervalMs, 500)
        XCTAssertTrue(c.readVolumeOnStartup)
        XCTAssertEqual(c.defaultVolume, 60)
    }

    func testDefaultVolumeClampedHigh() {
        let c = Config(monitorId: "test", defaultVolume: 200)
        XCTAssertEqual(c.defaultVolume, 100)
    }

    func testDefaultVolumeClampedLow() {
        let c = Config(monitorId: "test", defaultVolume: -5)
        XCTAssertEqual(c.defaultVolume, 0)
    }

    // MARK: - Paths

    func testConfigFilePathContainsDDCVolume() {
        XCTAssertTrue(Config.configFilePath.contains("ddc-volume"))
        XCTAssertTrue(Config.configFilePath.hasSuffix("config.json"))
    }

    func testSocketPathContainsDDCVolume() {
        XCTAssertTrue(Config.socketPath.contains("ddc-volume"))
        XCTAssertTrue(Config.socketPath.hasSuffix(".sock"))
    }

    // MARK: - Load from file

    func testLoadFromFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ddc-volume-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("config.json")
        let json = """
        {
            "monitorId": "TEST-MONITOR",
            "m1ddcPath": "/opt/homebrew/bin/m1ddc",
            "minIntervalMs": 500,
            "readVolumeOnStartup": true,
            "defaultVolume": 60
        }
        """
        try json.write(to: file, atomically: true, encoding: .utf8)

        let config = try Config.load(from: file.path)
        XCTAssertEqual(config.monitorId, "TEST-MONITOR")
    }

    func testLoadMissingFileThrows() {
        XCTAssertThrowsError(try Config.load(from: "/nonexistent/path/config.json"))
    }
}
