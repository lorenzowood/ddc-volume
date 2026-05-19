import XCTest
@testable import Common

final class MessagesTests: XCTestCase {

    // MARK: - Command.parse

    func testParseUp() {
        guard case .up(5) = Command.parse("UP 5") else { XCTFail(); return }
    }

    func testParseUpCaseInsensitive() {
        guard case .up(10) = Command.parse("up 10") else { XCTFail(); return }
    }

    func testParseDown() {
        guard case .down(3) = Command.parse("DOWN 3") else { XCTFail(); return }
    }

    func testParseSet() {
        guard case .set(75) = Command.parse("SET 75") else { XCTFail(); return }
    }

    func testParseGet() {
        guard case .get = Command.parse("GET") else { XCTFail(); return }
    }

    func testParseMute() {
        guard case .mute = Command.parse("MUTE") else { XCTFail(); return }
    }

    func testParseUnmute() {
        guard case .unmute = Command.parse("UNMUTE") else { XCTFail(); return }
    }

    func testParseToggleMute() {
        guard case .toggleMute = Command.parse("TOGGLEMUTE") else { XCTFail(); return }
    }

    func testParseUpMissingArg() {
        XCTAssertNil(Command.parse("UP"))
    }

    func testParseUpNonInteger() {
        XCTAssertNil(Command.parse("UP abc"))
    }

    func testParseUpNegative() {
        XCTAssertNil(Command.parse("UP -5"))
    }

    func testParseDownMissingArg() {
        XCTAssertNil(Command.parse("DOWN"))
    }

    func testParseSetMissingArg() {
        XCTAssertNil(Command.parse("SET"))
    }

    func testParseUnknown() {
        XCTAssertNil(Command.parse("REBOOT"))
    }

    func testParseEmpty() {
        XCTAssertNil(Command.parse(""))
    }

    func testParseWithLeadingWhitespace() {
        guard case .up(5) = Command.parse("  UP 5  ") else { XCTFail(); return }
    }

    // MARK: - Command.serialize

    func testSerializeUp() {
        XCTAssertEqual(Command.up(5).serialize(), "UP 5")
    }

    func testSerializeDown() {
        XCTAssertEqual(Command.down(10).serialize(), "DOWN 10")
    }

    func testSerializeSet() {
        XCTAssertEqual(Command.set(50).serialize(), "SET 50")
    }

    func testSerializeGet() {
        XCTAssertEqual(Command.get.serialize(), "GET")
    }

    // MARK: - StatusResponse

    func testSerializeWithLastSent() {
        let r = StatusResponse(desiredVolume: 50, lastSentVolume: 45, isMuted: false)
        XCTAssertEqual(r.serialize(), "STATUS desired=50 lastSent=45 muted=false")
    }

    func testSerializeWithNilLastSent() {
        let r = StatusResponse(desiredVolume: 60, lastSentVolume: nil, isMuted: true)
        XCTAssertEqual(r.serialize(), "STATUS desired=60 lastSent=- muted=true")
    }

    func testParseStatusResponse() {
        let r = StatusResponse.parse("STATUS desired=50 lastSent=45 muted=false")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.desiredVolume, 50)
        XCTAssertEqual(r?.lastSentVolume, 45)
        XCTAssertEqual(r?.isMuted, false)
    }

    func testParseStatusResponseNilLastSent() {
        let r = StatusResponse.parse("STATUS desired=60 lastSent=- muted=true")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.desiredVolume, 60)
        XCTAssertNil(r?.lastSentVolume)
        XCTAssertEqual(r?.isMuted, true)
    }

    func testParseStatusResponseRoundtrip() {
        let original = StatusResponse(desiredVolume: 72, lastSentVolume: 70, isMuted: false)
        let parsed = StatusResponse.parse(original.serialize())
        XCTAssertEqual(parsed?.desiredVolume, original.desiredVolume)
        XCTAssertEqual(parsed?.lastSentVolume, original.lastSentVolume)
        XCTAssertEqual(parsed?.isMuted, original.isMuted)
    }

    func testParseInvalidStatusResponse() {
        XCTAssertNil(StatusResponse.parse("ERROR unknown command"))
        XCTAssertNil(StatusResponse.parse(""))
        XCTAssertNil(StatusResponse.parse("STATUS desired=abc"))
    }
}
