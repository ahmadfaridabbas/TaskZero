import Foundation

enum CleanupItemOutcome: String, Codable, Sendable {
    case terminatedGracefully
    case forceTerminated
    case couldNotTerminate
    case skipped
    case dryRun

    var displayName: String {
        switch self {
        case .terminatedGracefully:
            return "Closed gracefully"
        case .forceTerminated:
            return "Force terminated"
        case .couldNotTerminate:
            return "Could not close"
        case .skipped:
            return "Skipped"
        case .dryRun:
            return "Preview only"
        }
    }
}

struct CleanupItemResult: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let process: TaskZeroProcess
    let outcome: CleanupItemOutcome
    let detail: String

    init(id: UUID = UUID(), process: TaskZeroProcess, outcome: CleanupItemOutcome, detail: String) {
        self.id = id
        self.process = process
        self.outcome = outcome
        self.detail = detail
    }
}

struct CleanupPreview: Sendable {
    let generatedAt: Date
    let applications: [TaskZeroProcess]
    let backgroundProcesses: [TaskZeroProcess]
    let protectedProcesses: [TaskZeroProcess]
    let excludedProcesses: [TaskZeroProcess]

    var eligibleProcesses: [TaskZeroProcess] {
        applications + backgroundProcesses
    }

    var eligibleCount: Int {
        applications.count + backgroundProcesses.count
    }
}

struct CleanupResult: Codable, Sendable, Identifiable {
    let startedAt: Date
    let completedAt: Date
    let items: [CleanupItemResult]
    let protectedCount: Int
    let excludedCount: Int
    let dryRun: Bool

    var id: String {
        String(startedAt.timeIntervalSince1970)
    }

    var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }

    var applications: [CleanupItemResult] {
        items.filter { $0.process.isApplication }
    }

    var backgroundProcesses: [CleanupItemResult] {
        items.filter { !$0.process.isApplication }
    }

    var gracefulCount: Int {
        items.count(where: { $0.outcome == .terminatedGracefully })
    }

    var forceTerminatedCount: Int {
        items.count(where: { $0.outcome == .forceTerminated })
    }

    var failureCount: Int {
        items.count(where: { $0.outcome == .couldNotTerminate })
    }

    var skippedCount: Int {
        items.count(where: { $0.outcome == .skipped })
    }
}
