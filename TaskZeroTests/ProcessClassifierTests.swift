import XCTest
@testable import TaskZero

final class ProcessClassifierTests: XCTestCase {
    func testAppleSignatureIsClassifiedAsApple() {
        let classifier = ProcessClassifier()
        let process = makeProcess(signature: .appleSigned, path: "/Applications/System.app/Contents/MacOS/System")

        XCTAssertEqual(classifier.baseClassification(for: process), .apple)
    }

    func testVerifiedThirdPartyBackgroundProcessIsClassifiedAsThirdParty() {
        let classifier = ProcessClassifier()
        let process = makeProcess(signature: .developerID, path: "/Applications/Example.app/Contents/MacOS/Example")

        XCTAssertEqual(classifier.baseClassification(for: process), .thirdParty)
    }

    func testUnknownSignatureIsNotClassifiedAsSafeThirdParty() {
        let classifier = ProcessClassifier()
        let process = makeProcess(signature: .unknown, path: "/Users/test/Library/Example/worker")

        XCTAssertEqual(classifier.baseClassification(for: process), .unknown)
    }

    private func makeProcess(signature: CodeSignatureStatus, path: String) -> TaskZeroProcess {
        TaskZeroProcess(
            pid: 301,
            parentPID: 1,
            name: "Example",
            executablePath: path,
            userID: UInt32(getuid()),
            userName: NSUserName(),
            bundleIdentifier: "com.example.Example",
            signatureStatus: signature,
            signingIdentifier: "com.example.Example",
            teamIdentifier: "TEAM123",
            startTime: Date(),
            state: .running,
            isApplication: false,
            memoryBytes: 1,
            cpuTimeSeconds: 0,
            classification: .unknown,
            protectionReason: nil
        )
    }
}
