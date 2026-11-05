import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var preview: CleanupPreview?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isPreparingPreview = false
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var lastResult: CleanupResult?
    @Published var selectedPIDs: Set<Int32> = []

    let preferences: PreferencesStore
    let cleanupManager: CleanupManager
    let inspector: ProcessInspector

    private let notificationManager: NotificationManager

    init(
        preferences: PreferencesStore,
        inspector: ProcessInspector = ProcessInspector(),
        applicationManager: ApplicationOperating? = nil,
        processManager: ProcessOperating? = nil,
        safetyManager: ProcessSafetyManager = ProcessSafetyManager(),
        notificationManager: NotificationManager = NotificationManager()
    ) {
        self.preferences = preferences
        self.inspector = inspector
        self.notificationManager = notificationManager
        let applications = applicationManager ?? ApplicationManager()
        let processes = processManager ?? ProcessManager(inspector: inspector)
        self.cleanupManager = CleanupManager(
            inspector: inspector,
            applicationManager: applications,
            processManager: processes,
            safetyManager: safetyManager
        )
    }

    var applicationCount: Int {
        preview?.applications.count ?? 0
    }

    var backgroundProcessCount: Int {
        preview?.backgroundProcesses.count ?? 0
    }

    var protectedCount: Int {
        preview?.protectedProcesses.count ?? 0
    }

    var excludedCount: Int {
        preview?.excludedProcesses.count ?? 0
    }

    var eligibleCount: Int {
        preview?.eligibleCount ?? 0
    }

    var isCleaning: Bool {
        cleanupManager.isCleaning
    }

    func refresh() async {
        guard !isRefreshing, !isCleaning else { return }
        isRefreshing = true
        statusMessage = "Inspecting processes…"
        let newPreview = await cleanupManager.makePreview(
            configuration: preferences.configuration,
            exclusions: preferences.exclusions
        )
        preview = newPreview
        selectedPIDs = Self.defaultSelection(for: newPreview)
        lastRefreshed = Date()
        statusMessage = "Ready"
        isRefreshing = false
    }

    func preparePreview() async -> CleanupPreview {
        isPreparingPreview = true
        statusMessage = "Preparing preview…"
        let newPreview = await cleanupManager.makePreview(
            configuration: preferences.configuration,
            exclusions: preferences.exclusions
        )
        preview = newPreview
        selectedPIDs = Self.defaultSelection(for: newPreview)
        lastRefreshed = Date()
        statusMessage = "Ready"
        isPreparingPreview = false
        return newPreview
    }

    /// By default only user-facing applications are pre-selected. Background helper
    /// processes (for example a browser's many crashpad/helper children) are left
    /// unchecked so the user opts into stopping them rather than closing dozens of
    /// helpers implicitly. "Select all" still selects everything eligible.
    private static func defaultSelection(for preview: CleanupPreview) -> Set<Int32> {
        Set(preview.applications.map(\.pid))
    }

    func toggleSelection(for pid: Int32) {
        if selectedPIDs.contains(pid) {
            selectedPIDs.remove(pid)
        } else {
            selectedPIDs.insert(pid)
        }
    }

    func selectAllEligible() {
        selectedPIDs = Set(preview?.eligibleProcesses.map(\.pid) ?? [])
    }

    func deselectAllEligible() {
        selectedPIDs.removeAll()
    }

    func runCleanup() async -> CleanupResult? {
        guard let preview else { return nil }
        guard !selectedPIDs.isEmpty else { return nil }
        statusMessage = "Cleaning…"
        let result = await cleanupManager.clean(
            preview: preview,
            selectedPIDs: selectedPIDs,
            configuration: preferences.configuration
        )
        guard let result else { return nil }
        lastResult = result
        preferences.addHistory(result)
        statusMessage = result.failureCount > 0 ? "Finished with issues" : "Cleanup complete"

        if preferences.configuration.showNotifications {
            Task { [notificationManager] in
                await notificationManager.requestAuthorization()
                await notificationManager.sendCleanupCompleted(result)
            }
        }
        return result
    }

    func cancelCleanup() {
        guard isCleaning else { return }
        statusMessage = "Cancelling…"
        cleanupManager.cancelCleanup()
    }

    func processMonitorViewModel() -> ProcessMonitorViewModel {
        ProcessMonitorViewModel(
            inspector: inspector,
            safetyManager: ProcessSafetyManager(),
            exclusions: preferences.exclusions
        )
    }
}
