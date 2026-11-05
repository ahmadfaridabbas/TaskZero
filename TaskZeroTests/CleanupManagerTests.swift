import XCTest
import Darwin
@testable import TaskZero

@MainActor
final class CleanupManagerTests: XCTestCase {
    func testGracefulBackgroundTerminationIsRecorded() async {
        let process = makeProcess(pid: 700)
        let processManager = MockProcessManager(behaviour: .termExits)
        let manager = CleanupManager(
            inspector: ProcessInspector(),
            applicationManager: MockApplicationManager(),
            processManager: processManager,
            safetyManager: ProcessSafetyManager(currentUserID: process.userID, ownProcessID: 999)
        )
        let preview = CleanupPreview(
            generatedAt: Date(),
            applications: [],
            backgroundProcesses: [process],
            protectedProcesses: [],
            excludedProcesses: []
        )

        let result = await manager.clean(
            preview: preview,
            selectedPIDs: [process.pid],
            configuration: testConfiguration()
        )

        XCTAssertEqual(result?.gracefulCount, 1)
        XCTAssertEqual(result?.forceTerminatedCount, 0)
        XCTAssertEqual(processManager.sentSignals, [SIGTERM])
    }

    func testForceTerminationRequiresIdentityRevalidation() async {
        let process = makeProcess(pid: 701)
        let processManager = MockProcessManager(behaviour: .killExits)
        let manager = CleanupManager(
            inspector: ProcessInspector(),
            applicationManager: MockApplicationManager(),
            processManager: processManager,
            safetyManager: ProcessSafetyManager(currentUserID: process.userID, ownProcessID: 999)
        )
        let preview = CleanupPreview(
            generatedAt: Date(),
            applications: [],
            backgroundProcesses: [process],
            protectedProcesses: [],
            excludedProcesses: []
        )

        let result = await manager.clean(
            preview: preview,
            selectedPIDs: [process.pid],
            configuration: testConfiguration()
        )

        XCTAssertEqual(result?.forceTerminatedCount, 1)
        XCTAssertEqual(processManager.sentSignals, [SIGTERM, SIGKILL])
    }

    func testCancellationStopsCleanupAndRecordsRemainingAsSkipped() async {
        let first = makeProcess(pid: 800)
        let second = makeProcess(pid: 801)
        let processManager = MockProcessManager(behaviour: .hold)
        let manager = CleanupManager(
            inspector: ProcessInspector(),
            applicationManager: MockApplicationManager(),
            processManager: processManager,
            safetyManager: ProcessSafetyManager(currentUserID: first.userID, ownProcessID: 999)
        )
        let preview = CleanupPreview(
            generatedAt: Date(),
            applications: [],
            backgroundProcesses: [first, second],
            protectedProcesses: [],
            excludedProcesses: []
        )
        var configuration = testConfiguration()
        configuration.backgroundProcessTimeout = CleanupConfiguration.maximumTimeout

        let task = Task {
            await manager.clean(preview: preview, selectedPIDs: [first.pid, second.pid], configuration: configuration)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        manager.cancelCleanup()
        let result = await task.value

        // No item should be force terminated after cancellation, and every selected
        // item is accounted for as skipped (the processes never exit in this mock).
        XCTAssertEqual(result?.forceTerminatedCount, 0)
        XCTAssertEqual(result?.skippedCount, 2)
        XCTAssertFalse(processManager.sentSignals.contains(SIGKILL))
        XCTAssertFalse(manager.isCleaning)
    }

    func testOverlappingCleanupIsRejected() async {
        let process = makeProcess(pid: 702)
        let processManager = MockProcessManager(behaviour: .hold)
        let manager = CleanupManager(
            inspector: ProcessInspector(),
            applicationManager: MockApplicationManager(),
            processManager: processManager,
            safetyManager: ProcessSafetyManager(currentUserID: process.userID, ownProcessID: 999)
        )
        let preview = CleanupPreview(generatedAt: Date(), applications: [], backgroundProcesses: [process], protectedProcesses: [], excludedProcesses: [])

        var configuration = testConfiguration()
        configuration.backgroundProcessTimeout = 0.05
        let first = Task {
            await manager.clean(preview: preview, selectedPIDs: [process.pid], configuration: configuration)
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertTrue(manager.isCleaning)
        let result = await manager.clean(preview: preview, selectedPIDs: [process.pid], configuration: configuration)
        _ = await first.value

        XCTAssertNil(result)
    }

    private func testConfiguration() -> CleanupConfiguration {
        var configuration = CleanupConfiguration()
        configuration.backgroundProcessTimeout = 0
        configuration.gracefulTerminationTimeout = 0
        return configuration
    }

    private func makeProcess(pid: Int32) -> TaskZeroProcess {
        TaskZeroProcess(
            pid: pid,
            parentPID: 1,
            name: "ExampleWorker",
            executablePath: "/Users/test/Library/ExampleWorker",
            userID: UInt32(getuid()),
            userName: "test",
            bundleIdentifier: nil,
            signatureStatus: .developerID,
            signingIdentifier: "com.example.worker",
            teamIdentifier: "TEAM123",
            startTime: Date(),
            state: .running,
            isApplication: false,
            memoryBytes: nil,
            cpuTimeSeconds: nil,
            classification: .thirdParty,
            protectionReason: nil
        )
    }
}

@MainActor
private final class MockApplicationManager: ApplicationOperating {
    func discoverApplications(from snapshot: [TaskZeroProcess]) -> [TaskZeroProcess] { [] }
    func requestGracefulTermination(of process: TaskZeroProcess) -> Bool { true }
    func forceTerminate(_ process: TaskZeroProcess) -> Bool { true }
}

private final class MockProcessManager: ProcessOperating {
    enum Behaviour {
        case termExits
        case killExits
        case hold
    }

    let behaviour: Behaviour
    var running = true
    var sentSignals: [Int32] = []

    init(behaviour: Behaviour) {
        self.behaviour = behaviour
    }

    func isRunning(_ process: TaskZeroProcess) -> Bool { running }
    func identityMatches(_ process: TaskZeroProcess) -> Bool { true }
    func signatureMatches(_ process: TaskZeroProcess) -> Bool { true }

    func send(signal: Int32, to process: TaskZeroProcess) -> SignalSendResult {
        sentSignals.append(signal)
        if signal == SIGTERM, behaviour == .termExits {
            running = false
        }
        if signal == SIGKILL, behaviour == .killExits {
            running = false
        }
        return .sent
    }
}
