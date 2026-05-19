import XCTest
@testable import Common

final class MonitorControllerTests: XCTestCase {

    func testParseTypicalOutput() {
        let raw = """
        [1] DELL U4025QW (078C54FE-38D5-4991-88C0-F52A8804478C)
        [2] DELL3007WFPHC (6C9AB635-5BFD-417A-808F-F130FF674BAF)
        """
        let monitors = MonitorController.parseMonitorList(raw)
        XCTAssertEqual(monitors.count, 2)
        XCTAssertEqual(monitors[0].name, "DELL U4025QW")
        XCTAssertEqual(monitors[0].id,   "078C54FE-38D5-4991-88C0-F52A8804478C")
        XCTAssertEqual(monitors[1].name, "DELL3007WFPHC")
        XCTAssertEqual(monitors[1].id,   "6C9AB635-5BFD-417A-808F-F130FF674BAF")
    }

    func testParseSingleMonitor() {
        let raw = "[1] LG UltraFine 4K (AABBCCDD-1234-5678-9ABC-DEF012345678)"
        let monitors = MonitorController.parseMonitorList(raw)
        XCTAssertEqual(monitors.count, 1)
        XCTAssertEqual(monitors[0].name, "LG UltraFine 4K")
        XCTAssertEqual(monitors[0].id,   "AABBCCDD-1234-5678-9ABC-DEF012345678")
    }

    func testParseIgnoresBlankLines() {
        let raw = "\n[1] DELL U4025QW (078C54FE-38D5-4991-88C0-F52A8804478C)\n\n"
        let monitors = MonitorController.parseMonitorList(raw)
        XCTAssertEqual(monitors.count, 1)
    }

    func testParseIgnoresNonMatchingLines() {
        let raw = """
        Searching for displays...
        [1] DELL U4025QW (078C54FE-38D5-4991-88C0-F52A8804478C)
        Done.
        """
        let monitors = MonitorController.parseMonitorList(raw)
        XCTAssertEqual(monitors.count, 1)
    }

    func testParseEmptyOutput() {
        XCTAssertEqual(MonitorController.parseMonitorList("").count, 0)
    }

    func testParseNameWithSpaces() {
        let raw = "[1] Samsung Odyssey G9 (11223344-AABB-CCDD-EEFF-001122334455)"
        let monitors = MonitorController.parseMonitorList(raw)
        XCTAssertEqual(monitors[0].name, "Samsung Odyssey G9")
    }
}
