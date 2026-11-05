import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var newExclusionKind: ExclusionKind = .processName
    @State private var newExclusionValue = ""
    @State private var newExclusionReason = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image("TaskZeroMenuBarGlyph")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(TaskZeroPalette.cream)
                    .frame(width: 38, height: 38)
                    .background(TaskZeroPalette.cocoa, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("TaskZero Settings").font(.headline)
                    Text("Personalize your cleanup experience")
                        .font(.caption).foregroundStyle(TaskZeroPalette.secondaryText)
                }
                Spacer()
                Text(preferences.configuration.appearance.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(TaskZeroPalette.accent)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(TaskZeroPalette.accent.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.top, 15)
            .padding(.bottom, 5)

            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "slider.horizontal.3") }
                cleanupTab
                    .tabItem { Label("Cleanup", systemImage: "sparkles") }
                exclusionsTab
                    .tabItem { Label("Exclusions", systemImage: "eye.slash") }
                appearanceTab
                    .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }
                AboutView()
                    .tabItem { Label("About", systemImage: "info.circle") }
            }
        }
        .frame(width: 680, height: 510)
        .background(TaskZeroPalette.canvas)
        .foregroundStyle(TaskZeroPalette.primaryText)
        .tint(TaskZeroPalette.accent)
    }

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { preferences.configuration.launchAtLogin },
                    set: { preferences.setLaunchAtLogin($0) }
                ))
                Toggle("Start in menu-bar mode", isOn: Binding(
                    get: { preferences.configuration.startInMenuBarMode },
                    set: { enabled in
                        preferences.update { $0.startInMenuBarMode = enabled }
                        NSApp.setActivationPolicy(enabled ? .accessory : .regular)
                    }
                ))
                Text("TaskZero is designed to stay in the menu bar and does not add a Dock icon.")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
            Section("Feedback") {
                Toggle("Show notifications after cleanup", isOn: configurationBinding(\.showNotifications))
                Toggle("Ask for confirmation before cleanup", isOn: configurationBinding(\.showCleanupConfirmation))
                Toggle("Automatically display cleanup summary", isOn: configurationBinding(\.automaticallyDisplaySummary))
            }
            if let error = preferences.launchAtLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.warning)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(TaskZeroPalette.canvas)
    }

    private var cleanupTab: some View {
        Form {
            Section("Termination") {
                Toggle("Include background processes", isOn: configurationBinding(\.includeBackgroundProcesses))
                Toggle("Enable force termination", isOn: configurationBinding(\.enableForceTermination))
                Text("Graceful termination always happens first. Force termination is only attempted for verified, user-owned items that remain running.")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
            Section("Timeouts") {
                Stepper(
                    value: configurationBinding(\.gracefulTerminationTimeout),
                    in: CleanupConfiguration.minimumTimeout...CleanupConfiguration.maximumTimeout,
                    step: 1
                ) {
                    HStack {
                        Text("Application graceful timeout")
                        Spacer()
                        Text("\(Int(preferences.configuration.gracefulTerminationTimeout)) seconds")
                            .foregroundStyle(TaskZeroPalette.secondaryText)
                            .monospacedDigit()
                    }
                }
                Stepper(
                    value: configurationBinding(\.backgroundProcessTimeout),
                    in: CleanupConfiguration.minimumTimeout...CleanupConfiguration.maximumTimeout,
                    step: 1
                ) {
                    HStack {
                        Text("Background process timeout")
                        Spacer()
                        Text("\(Int(preferences.configuration.backgroundProcessTimeout)) seconds")
                            .foregroundStyle(TaskZeroPalette.secondaryText)
                            .monospacedDigit()
                    }
                }
                Text("Timeouts are limited to \(Int(CleanupConfiguration.minimumTimeout))–\(Int(CleanupConfiguration.maximumTimeout)) seconds.")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
            Section("Review") {
                Toggle("Show process preview before cleanup", isOn: configurationBinding(\.showProcessPreview))
                Text("Unknown or unverifiable identities are skipped automatically.")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(TaskZeroPalette.canvas)
    }

    private var exclusionsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Excluded software is always skipped during cleanup. Use this for VPNs, security tools, sync clients, audio services, and virtualization software.")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.primaryText)
            } icon: {
                Image(systemName: "eye.slash.fill").foregroundStyle(TaskZeroPalette.cream)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TaskZeroPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(TaskZeroPalette.separator, lineWidth: 1))
            HStack {
                Picker("Type", selection: $newExclusionKind) {
                    ForEach(ExclusionKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .frame(width: 160)
                TextField(newExclusionKind == .processName ? "Process name" : "com.example.App", text: $newExclusionValue)
                TextField("Reason (optional)", text: $newExclusionReason)
                Button("Add") { addExclusion() }
                    .disabled(newExclusionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Divider()
            if preferences.exclusions.isEmpty {
                EmptyStateView(
                    title: "No exclusions",
                    symbol: "eye.slash",
                    message: "Add a process name or application bundle identifier above."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(preferences.exclusions) { exclusion in
                        HStack {
                            Image(systemName: exclusion.kind == .processName ? "gearshape" : "app")
                                .foregroundStyle(TaskZeroPalette.secondaryText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exclusion.value)
                                Text("\(exclusion.kind.displayName) · \(exclusion.reason)")
                                    .font(.caption)
                                    .foregroundStyle(TaskZeroPalette.secondaryText)
                            }
                            Spacer()
                            Button {
                                preferences.removeExclusion(exclusion)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove exclusion \(exclusion.value)")
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(TaskZeroPalette.canvas)
            }
        }
        .padding(14)
    }

    private var appearanceTab: some View {
        Form {
            Section("Appearance") {
                Picker("Color scheme", selection: configurationBinding(\.appearance)) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text("Choose System to follow macOS, or select Light or Dark to set TaskZero’s appearance directly. Changes apply to the menu, monitor, and settings windows.")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(TaskZeroPalette.canvas)
    }

    private func addExclusion() {
        preferences.addExclusion(
            kind: newExclusionKind,
            value: newExclusionValue,
            reason: newExclusionReason.isEmpty ? nil : newExclusionReason
        )
        newExclusionValue = ""
        newExclusionReason = ""
    }

    private func configurationBinding<Value>(_ keyPath: WritableKeyPath<CleanupConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { preferences.configuration[keyPath: keyPath] },
            set: { newValue in
                preferences.update { configuration in
                    configuration[keyPath: keyPath] = newValue
                }
            }
        )
    }

}
