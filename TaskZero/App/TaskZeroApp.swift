import SwiftUI

@main
struct TaskZeroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences: PreferencesStore
    @StateObject private var viewModel: MenuBarViewModel

    init() {
        let preferences = PreferencesStore()
        _preferences = StateObject(wrappedValue: preferences)
        _viewModel = StateObject(wrappedValue: MenuBarViewModel(preferences: preferences))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(preferences)
                .environmentObject(viewModel)
                .preferredColorScheme(preferredColorScheme)
                .tint(TaskZeroPalette.accent)
        } label: {
            Image("TaskZeroMenuBarGlyph")
                .renderingMode(.template)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(TaskZeroPalette.accent)
                .accessibilityLabel(TaskZeroConstants.productName)
        }
        .menuBarExtraStyle(.window)

        Window("Process Monitor", id: "process-monitor") {
            ProcessMonitorView()
                .environmentObject(preferences)
                .preferredColorScheme(preferredColorScheme)
        }

        Settings {
            SettingsView()
                .environmentObject(preferences)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch preferences.configuration.appearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
