import XCTest
@testable import TaskZero

final class ProcessInspectorTests: XCTestCase {
    func testSnapshotIncludesTheCurrentProcess() async {
        let snapshot = await ProcessInspector().snapshot()
        let currentPID = Int32(ProcessInfo.processInfo.processIdentifier)

        XCTAssertFalse(snapshot.isEmpty)
        XCTAssertTrue(snapshot.contains { $0.pid == currentPID })
    }
}
