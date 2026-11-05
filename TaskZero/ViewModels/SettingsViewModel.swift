import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    let preferences: PreferencesStore
    @Published var newExclusionValue = ""
    @Published var newExclusionKind: ExclusionKind = .processName
    @Published var newExclusionReason = ""

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func addExclusion() {
        preferences.addExclusion(
            kind: newExclusionKind,
            value: newExclusionValue,
            reason: newExclusionReason.isEmpty ? nil : newExclusionReason
        )
        newExclusionValue = ""
        newExclusionReason = ""
    }
}
