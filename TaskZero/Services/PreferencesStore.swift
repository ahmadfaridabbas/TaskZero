import Combine
import Foundation
import AppKit

@MainActor
final class PreferencesStore: ObservableObject {
    @Published private(set) var configuration: CleanupConfiguration
    @Published private(set) var exclusions: [ExclusionRule]
    @Published private(set) var history: [CleanupResult]
    @Published private(set) var launchAtLoginError: String?

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: TaskZeroConstants.preferencesKey),
           let stored = try? JSONDecoder().decode(StoredPreferences.self, from: data)
        {
            configuration = stored.configuration
            exclusions = stored.exclusions
        } else {
            configuration = CleanupConfiguration()
            exclusions = []
        }

        if let data = defaults.data(forKey: TaskZeroConstants.historyKey),
           let storedHistory = try? JSONDecoder().decode([CleanupResult].self, from: data)
        {
            history = storedHistory
        } else {
            history = []
        }
    }

    static func startInMenuBarMode(defaults: UserDefaults = .standard) -> Bool {
        guard let data = defaults.data(forKey: TaskZeroConstants.preferencesKey),
              let stored = try? JSONDecoder().decode(StoredPreferences.self, from: data)
        else {
            return true
        }
        return stored.configuration.startInMenuBarMode
    }

    static func applyStoredAppearance(defaults: UserDefaults = .standard) {
        guard let data = defaults.data(forKey: TaskZeroConstants.preferencesKey),
              let stored = try? JSONDecoder().decode(StoredPreferences.self, from: data)
        else { return }
        apply(stored.configuration.appearance, to: NSApp)
    }

    func update(_ update: (inout CleanupConfiguration) -> Void) {
        let previousAppearance = configuration.appearance
        update(&configuration)
        savePreferences()
        if configuration.appearance != previousAppearance {
            applyAppearance()
        }
    }

    func addExclusion(kind: ExclusionKind, value: String, reason: String? = nil) {
        let cleanedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedValue.isEmpty else { return }
        guard !exclusions.contains(where: {
            $0.kind == kind && ProcessUtilities.normalized($0.value) == ProcessUtilities.normalized(cleanedValue)
        }) else { return }
        exclusions.append(ExclusionRule(kind: kind, value: cleanedValue, reason: reason))
        savePreferences()
    }

    func removeExclusion(_ exclusion: ExclusionRule) {
        exclusions.removeAll { $0.id == exclusion.id }
        savePreferences()
    }

    func addHistory(_ result: CleanupResult) {
        history.insert(result, at: 0)
        if history.count > TaskZeroConstants.historyLimit {
            history = Array(history.prefix(TaskZeroConstants.historyLimit))
        }
        if let data = try? encoder.encode(history) {
            defaults.set(data, forKey: TaskZeroConstants.historyKey)
        }
    }

    func clearHistory() {
        history.removeAll()
        defaults.removeObject(forKey: TaskZeroConstants.historyKey)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            configuration.launchAtLogin = enabled
            launchAtLoginError = nil
            savePreferences()
        } catch {
            launchAtLoginError = error.localizedDescription
        }
    }

    private func savePreferences() {
        let stored = StoredPreferences(configuration: configuration, exclusions: exclusions)
        if let data = try? encoder.encode(stored) {
            defaults.set(data, forKey: TaskZeroConstants.preferencesKey)
        }
    }

    private func applyAppearance() {
        Self.apply(configuration.appearance, to: NSApp)
    }

    private static func apply(_ appearance: AppearanceMode, to app: NSApplication) {
        switch appearance {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .aqua)
        case .dark:
            app.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

private struct StoredPreferences: Codable {
    let configuration: CleanupConfiguration
    let exclusions: [ExclusionRule]
}
