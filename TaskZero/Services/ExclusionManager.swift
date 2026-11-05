import Foundation

struct ExclusionManager: Sendable {
    func matchingRule(for process: TaskZeroProcess, rules: [ExclusionRule]) -> ExclusionRule? {
        rules.first { rule in
            switch rule.kind {
            case .processName:
                return ProcessUtilities.normalized(rule.value) == ProcessUtilities.normalized(process.name)
            case .bundleIdentifier:
                guard let bundleIdentifier = process.bundleIdentifier else { return false }
                return ProcessUtilities.normalized(rule.value) == ProcessUtilities.normalized(bundleIdentifier)
            }
        }
    }
}
