import Foundation
import Darwin

final class ProcessSafetyManager: @unchecked Sendable {
    let currentUserID: UInt32
    let ownProcessID: Int32
    private let classifier: ProcessClassifier
    private let exclusionManager = ExclusionManager()

    init(currentUserID: UInt32 = UInt32(getuid()), ownProcessID: Int32 = Int32(getpid())) {
        self.currentUserID = currentUserID
        self.ownProcessID = ownProcessID
        self.classifier = ProcessClassifier()
    }

    func decision(for process: TaskZeroProcess, exclusions: [ExclusionRule]) -> SafetyDecision {
        guard process.pid > 0 else {
            return .protected(reason: "Invalid process identifier")
        }
        guard process.pid != ownProcessID else {
            return .protected(reason: "TaskZero protects itself")
        }
        guard process.userID == currentUserID else {
            return .protected(reason: "Owned by another user")
        }

        if TaskZeroConstants.protectedProcessNames.contains(where: {
            ProcessUtilities.normalized($0) == ProcessUtilities.normalized(process.name)
        }) {
            return .protected(reason: "Critical macOS session process")
        }

        if ProcessUtilities.isWithinProtectedLocation(process.executablePath) && !process.isApplication {
            return .protected(reason: "Executable is in a protected system location")
        }

        switch classifier.baseClassification(for: process) {
        case .apple:
            // Apple-signed regular GUI apps (for example Calendar or Calculator) can be
            // closed through NSRunningApplication. Apple background processes remain protected.
            if process.isApplication && process.signatureStatus == .appleSigned {
                if let exclusion = matchingExclusion(for: process, exclusions: exclusions) {
                    return .excluded(reason: exclusion.reason)
                }
                return .eligible
            }
            return .protected(reason: "Apple-signed or system process")
        case .unknown:
            return .protected(reason: "Process identity could not be verified")
        case .application, .thirdParty:
            if let exclusion = matchingExclusion(for: process, exclusions: exclusions) {
                return .excluded(reason: exclusion.reason)
            }
            return .eligible
        case .protected, .excluded:
            return .protected(reason: "Protected by policy")
        }
    }

    func classifiedProcess(_ process: TaskZeroProcess, exclusions: [ExclusionRule]) -> TaskZeroProcess {
        switch decision(for: process, exclusions: exclusions) {
        case .eligible:
            return process.replacing(
                classification: process.isApplication ? .application : .thirdParty,
                protectionReason: nil
            )
        case let .protected(reason):
            let base = classifier.baseClassification(for: process)
            return process.replacing(
                classification: base == .apple ? .apple : .protected,
                protectionReason: reason
            )
        case let .excluded(reason):
            return process.replacing(classification: .excluded, protectionReason: reason)
        }
    }

    private func matchingExclusion(for process: TaskZeroProcess, exclusions: [ExclusionRule]) -> ExclusionRule? {
        exclusionManager.matchingRule(for: process, rules: exclusions)
    }
}
