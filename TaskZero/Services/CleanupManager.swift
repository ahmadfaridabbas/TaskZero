import Combine
import Foundation
import OSLog
import Darwin

@MainActor
final class CleanupManager: ObservableObject {
    @Published private(set) var isCleaning = false
    @Published private(set) var lastResult: CleanupResult?

    private let inspector: ProcessInspector
    private let applicationManager: ApplicationOperating
    private let processManager: ProcessOperating
    private let safetyManager: ProcessSafetyManager
    private let logger = Logger(subsystem: TaskZeroConstants.bundleIdentifier, category: "cleanup")

    private var activeTask: Task<CleanupResult?, Never>?

    private enum ExitWaitResult {
        case exited
        case timedOut
        case identityChanged
        case cancelled
    }

    init(
        inspector: ProcessInspector,
        applicationManager: ApplicationOperating,
        processManager: ProcessOperating,
        safetyManager: ProcessSafetyManager
    ) {
        self.inspector = inspector
        self.applicationManager = applicationManager
        self.processManager = processManager
        self.safetyManager = safetyManager
    }

    func makePreview(
        configuration: CleanupConfiguration,
        exclusions: [ExclusionRule]
    ) async -> CleanupPreview {
        let snapshot = await inspector.snapshot()
        let applications = applicationManager.discoverApplications(from: snapshot)
        let applicationPIDs = Set(applications.map(\.pid))
        var eligibleApplications: [TaskZeroProcess] = []
        var eligibleBackground: [TaskZeroProcess] = []
        var protected: [TaskZeroProcess] = []
        var excluded: [TaskZeroProcess] = []

        for application in applications {
            classify(
                application,
                exclusions: exclusions,
                eligibleApplications: &eligibleApplications,
                eligibleBackground: &eligibleBackground,
                protected: &protected,
                excluded: &excluded
            )
        }

        for process in snapshot where !applicationPIDs.contains(process.pid) && !process.isApplication {
            classify(
                process,
                exclusions: exclusions,
                includeEligibleBackground: configuration.includeBackgroundProcesses,
                eligibleApplications: &eligibleApplications,
                eligibleBackground: &eligibleBackground,
                protected: &protected,
                excluded: &excluded
            )
        }

        return CleanupPreview(
            generatedAt: Date(),
            applications: eligibleApplications,
            backgroundProcesses: eligibleBackground,
            protectedProcesses: protected,
            excludedProcesses: excluded
        )
    }

    func clean(
        preview: CleanupPreview,
        selectedPIDs: Set<Int32>,
        configuration: CleanupConfiguration,
        dryRun: Bool = false
    ) async -> CleanupResult? {
        guard !isCleaning else { return nil }
        isCleaning = true

        let task = Task { () -> CleanupResult? in
            await performClean(
                preview: preview,
                selectedPIDs: selectedPIDs,
                configuration: configuration,
                dryRun: dryRun
            )
        }
        activeTask = task
        let result = await task.value
        activeTask = nil
        isCleaning = false
        return result
    }

    /// Requests cancellation of an in-flight cleanup. Items already processed are kept;
    /// remaining items are recorded as skipped. No new signals are sent after cancellation.
    func cancelCleanup() {
        activeTask?.cancel()
    }

    private func performClean(
        preview: CleanupPreview,
        selectedPIDs: Set<Int32>,
        configuration: CleanupConfiguration,
        dryRun: Bool
    ) async -> CleanupResult? {
        let startedAt = Date()
        let selected = preview.eligibleProcesses.filter { selectedPIDs.contains($0.pid) }
        let ordered = selected.filter(\.isApplication) + selected.filter { !$0.isApplication }
        var results: [CleanupItemResult] = []
        results.reserveCapacity(ordered.count)

        for process in ordered {
            if Task.isCancelled {
                results.append(CleanupItemResult(process: process, outcome: .skipped, detail: "Cancelled before processing"))
                continue
            }
            if dryRun {
                results.append(CleanupItemResult(process: process, outcome: .dryRun, detail: "No signal sent"))
            } else if process.isApplication {
                results.append(await cleanApplication(process, configuration: configuration))
            } else {
                results.append(await cleanBackgroundProcess(process, configuration: configuration))
            }
        }

        let result = CleanupResult(
            startedAt: startedAt,
            completedAt: Date(),
            items: results,
            protectedCount: preview.protectedProcesses.count,
            excludedCount: preview.excludedProcesses.count,
            dryRun: dryRun
        )
        lastResult = result
        logger.info("Cleanup finished: processed=\(results.count, privacy: .public), failures=\(result.failureCount, privacy: .public), cancelled=\(Task.isCancelled, privacy: .public)")
        return result
    }

    private func classify(
        _ process: TaskZeroProcess,
        exclusions: [ExclusionRule],
        includeEligibleBackground: Bool = true,
        eligibleApplications: inout [TaskZeroProcess],
        eligibleBackground: inout [TaskZeroProcess],
        protected: inout [TaskZeroProcess],
        excluded: inout [TaskZeroProcess]
    ) {
        switch safetyManager.decision(for: process, exclusions: exclusions) {
        case .eligible:
            let classified = process.replacing(
                classification: process.isApplication ? .application : .thirdParty,
                protectionReason: nil
            )
            if process.isApplication {
                eligibleApplications.append(classified)
            } else if includeEligibleBackground {
                eligibleBackground.append(classified)
            }
        case let .protected(reason):
            protected.append(process.replacing(classification: .protected, protectionReason: reason))
        case let .excluded(reason):
            excluded.append(process.replacing(classification: .excluded, protectionReason: reason))
        }
    }

    private func cleanApplication(
        _ process: TaskZeroProcess,
        configuration: CleanupConfiguration
    ) async -> CleanupItemResult {
        guard processManager.identityMatches(process), processManager.signatureMatches(process) else {
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "The process disappeared or its identity changed before cleanup"
            )
        }

        let requested = applicationManager.requestGracefulTermination(of: process)
        if !requested && !processManager.isRunning(process) {
            return CleanupItemResult(
                process: process,
                outcome: .terminatedGracefully,
                detail: "The application exited before the request completed"
            )
        }

        switch await waitForExit(process, timeout: configuration.gracefulTerminationTimeout) {
        case .exited:
            return CleanupItemResult(
                process: process,
                outcome: .terminatedGracefully,
                detail: "Closed after a graceful termination request"
            )
        case .identityChanged:
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "The process identity changed during graceful termination"
            )
        case .cancelled:
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "Cancelled while waiting for graceful termination"
            )
        case .timedOut:
            break
        }

        guard configuration.enableForceTermination else {
            return CleanupItemResult(
                process: process,
                outcome: .couldNotTerminate,
                detail: "The application did not exit before the graceful timeout"
            )
        }

        guard processManager.identityMatches(process), processManager.signatureMatches(process) else {
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "The process identity changed; force termination was skipped"
            )
        }

        guard applicationManager.forceTerminate(process) else {
            return CleanupItemResult(
                process: process,
                outcome: .couldNotTerminate,
                detail: "macOS refused the force-termination request"
            )
        }

        switch await waitForExit(process, timeout: configuration.backgroundProcessTimeout) {
        case .exited:
            return CleanupItemResult(
                process: process,
                outcome: .forceTerminated,
                detail: "Force terminated after the graceful timeout"
            )
        case .identityChanged:
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "The process identity changed after force termination"
            )
        case .cancelled:
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "Cancelled while waiting for force termination"
            )
        case .timedOut:
            break
        }
        return CleanupItemResult(
            process: process,
            outcome: .couldNotTerminate,
            detail: "The application remained running after force termination"
        )
    }

    private func cleanBackgroundProcess(
        _ process: TaskZeroProcess,
        configuration: CleanupConfiguration
    ) async -> CleanupItemResult {
        guard processManager.identityMatches(process), processManager.signatureMatches(process) else {
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "The process disappeared or its identity changed before cleanup"
            )
        }

        switch processManager.send(signal: SIGTERM, to: process) {
        case .alreadyExited:
            return CleanupItemResult(process: process, outcome: .terminatedGracefully, detail: "Already exited")
        case .identityChanged:
            return CleanupItemResult(process: process, outcome: .skipped, detail: "PID identity changed")
        case .permissionDenied:
            return CleanupItemResult(process: process, outcome: .couldNotTerminate, detail: "Permission denied")
        case let .failed(error):
            return CleanupItemResult(process: process, outcome: .couldNotTerminate, detail: error)
        case .sent:
            break
        }

        switch await waitForExit(process, timeout: configuration.backgroundProcessTimeout) {
        case .exited:
            return CleanupItemResult(
                process: process,
                outcome: .terminatedGracefully,
                detail: "Exited after SIGTERM"
            )
        case .identityChanged:
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "The process identity changed after SIGTERM"
            )
        case .cancelled:
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "Cancelled after SIGTERM; SIGKILL was not sent"
            )
        case .timedOut:
            break
        }

        guard configuration.enableForceTermination else {
            return CleanupItemResult(
                process: process,
                outcome: .couldNotTerminate,
                detail: "Still running after SIGTERM"
            )
        }

        guard processManager.identityMatches(process), processManager.signatureMatches(process) else {
            return CleanupItemResult(
                process: process,
                outcome: .skipped,
                detail: "The process identity changed; SIGKILL was skipped"
            )
        }

        switch processManager.send(signal: SIGKILL, to: process) {
        case .sent:
            switch await waitForExit(process, timeout: configuration.backgroundProcessTimeout) {
            case .exited:
                return CleanupItemResult(
                    process: process,
                    outcome: .forceTerminated,
                    detail: "Force terminated after SIGTERM"
                )
            case .identityChanged:
                return CleanupItemResult(
                    process: process,
                    outcome: .skipped,
                    detail: "The process identity changed after SIGKILL"
                )
            case .cancelled:
                return CleanupItemResult(
                    process: process,
                    outcome: .skipped,
                    detail: "Cancelled while waiting for SIGKILL to take effect"
                )
            case .timedOut:
                break
            }
            return CleanupItemResult(
                process: process,
                outcome: .couldNotTerminate,
                detail: "Still running after SIGKILL"
            )
        case .alreadyExited:
            return CleanupItemResult(process: process, outcome: .terminatedGracefully, detail: "Exited before SIGKILL")
        case .identityChanged:
            return CleanupItemResult(process: process, outcome: .skipped, detail: "PID identity changed")
        case .permissionDenied:
            return CleanupItemResult(process: process, outcome: .couldNotTerminate, detail: "Permission denied for SIGKILL")
        case let .failed(error):
            return CleanupItemResult(process: process, outcome: .couldNotTerminate, detail: error)
        }
    }

    private func waitForExit(_ process: TaskZeroProcess, timeout: TimeInterval) async -> ExitWaitResult {
        let timeout = max(0, timeout)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if !processManager.isRunning(process) {
                return .exited
            }
            if !processManager.identityMatches(process) {
                return .identityChanged
            }
            if Date() >= deadline {
                return .timedOut
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        } while !Task.isCancelled
        return .cancelled
    }
}
