import XCTest
@testable import TaskZero

final class ProcessSafetyManagerTests: XCTestCase {
    func testTaskZeroProtectsItsOwnPID() {
        let manager = ProcessSafetyManager(currentUserID: 501, ownProcessID: 42)
        let process = makeProcess(pid: 42, name: "TaskZero", userID: 501, signature: .developerID)

        XCTAssertEqual(manager.decision(for: process, exclusions: []), .protected(reason: "TaskZero protects itself"))
    }

    func testCriticalSessionProcessIsProtected() {
        let manager = ProcessSafetyManager(currentUserID: 501, ownProcessID: 99)
        let process = makeProcess(pid: 43, name: "Finder", userID: 501, signature: .appleSigned)

        XCTAssertEqual(manager.decision(for: process, exclusions: []), .protected(reason: "Critical macOS session process"))
    }

    func testRootOwnedProcessIsProtected() {
        let manager = ProcessSafetyManager(currentUserID: 501, ownProcessID: 99)
        let process = makeProcess(pid: 44, name: "Example", userID: 0, signature: .developerID)

        XCTAssertEqual(manager.decision(for: process, exclusions: []), .protected(reason: "Owned by another user"))
    }

    func testUnknownIdentityIsProtectedByDefault() {
        let manager = ProcessSafetyManager(currentUserID: 501, ownProcessID: 99)
        let process = makeProcess(pid: 45, name: "Example", userID: 501, signature: .unknown)

        XCTAssertEqual(manager.decision(for: process, exclusions: []), .protected(reason: "Process identity could not be verified"))
    }

    func testUserExclusionWinsBeforeEligibility() {
        let manager = ProcessSafetyManager(currentUserID: 501, ownProcessID: 99)
        let process = makeProcess(pid: 46, name: "VPNClient", userID: 501, signature: .developerID)
        let exclusion = ExclusionRule(kind: .processName, value: "vpnclient", reason: "VPN")

        XCTAssertEqual(manager.decision(for: process, exclusions: [exclusion]), .excluded(reason: "VPN"))
    }

    func testVerifiedUserOwnedThirdPartyProcessIsEligible() {
        let manager = ProcessSafetyManager(currentUserID: 501, ownProcessID: 99)
        let process = makeProcess(pid: 47, name: "Example", userID: 501, signature: .developerID)

        XCTAssertEqual(manager.decision(for: process, exclusions: []), .eligible)
    }

    private func makeProcess(pid: Int32, name: String, userID: UInt32, signature: CodeSignatureStatus) -> TaskZeroProcess {
        TaskZeroProcess(
            pid: pid,
            parentPID: 1,
            name: name,
            executablePath: "/Users/test/Library/Application Support/Example/worker",
            userID: userID,
            userName: "test",
            bundleIdentifier: "com.example.Example",
            signatureStatus: signature,
            signingIdentifier: "com.example.Example",
            teamIdentifier: "TEAM123",
            startTime: Date(),
            state: .running,
            isApplication: false,
            memoryBytes: nil,
            cpuTimeSeconds: nil,
            classification: .unknown,
            protectionReason: nil
        )
    }
}
