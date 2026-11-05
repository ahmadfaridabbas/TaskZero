import AppKit
import Combine
import Foundation

enum ProcessMonitorFilter: String, CaseIterable, Identifiable {
    case all
    case applications
    case background
    case apple
    case thirdParty
    case protected
    case excluded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "All processes"
        case .applications:
            return "Applications"
        case .background:
            return "Background processes"
        case .apple:
            return "Apple processes"
        case .thirdParty:
            return "Third-party processes"
        case .protected:
            return "Protected processes"
        case .excluded:
            return "Excluded processes"
        }
    }
}

@MainActor
final class ProcessMonitorViewModel: ObservableObject {
    @Published private(set) var processes: [TaskZeroProcess] = []
    @Published private(set) var isLoading = false
    @Published var filter: ProcessMonitorFilter = .all
    @Published var searchText = ""

    private let inspector: ProcessInspector
    private let safetyManager: ProcessSafetyManager
    private var exclusions: [ExclusionRule]

    init(
        inspector: ProcessInspector = ProcessInspector(),
        safetyManager: ProcessSafetyManager = ProcessSafetyManager(),
        exclusions: [ExclusionRule] = []
    ) {
        self.inspector = inspector
        self.safetyManager = safetyManager
        self.exclusions = exclusions
    }

    func updateExclusions(_ exclusions: [ExclusionRule]) {
        self.exclusions = exclusions
    }

    var filteredProcesses: [TaskZeroProcess] {
        processes.filter { process in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .applications:
                matchesFilter = process.isApplication
            case .background:
                matchesFilter = !process.isApplication
            case .apple:
                matchesFilter = process.classification == .apple
            case .thirdParty:
                matchesFilter = process.classification == .thirdParty || process.classification == .application
            case .protected:
                matchesFilter = process.classification == .protected
            case .excluded:
                matchesFilter = process.classification == .excluded
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesFilter }
            return matchesFilter && (
                process.displayName.localizedCaseInsensitiveContains(query)
                    || process.bundleIdentifier?.localizedCaseInsensitiveContains(query) == true
                    || process.pidLabel.localizedCaseInsensitiveContains(query)
            )
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        let snapshot = await inspector.snapshot()
        let runningApplicationPIDs = Set(NSWorkspace.shared.runningApplications.map { Int32($0.processIdentifier) })
        processes = snapshot.map { process in
            let applicationProcess = process.replacing(
                classification: process.classification,
                protectionReason: process.protectionReason,
                isApplication: runningApplicationPIDs.contains(process.pid)
            )
            let classified = safetyManager.classifiedProcess(applicationProcess, exclusions: exclusions)
            if classified.classification == .thirdParty && applicationProcess.isApplication {
                return classified.replacing(classification: .application)
            }
            return classified
        }
        isLoading = false
    }
}
