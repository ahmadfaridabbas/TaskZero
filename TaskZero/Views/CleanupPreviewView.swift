import AppKit
import SwiftUI

struct CleanupPreviewView: View {
    @EnvironmentObject private var viewModel: MenuBarViewModel
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingForceWarning = false
    @State private var isSubmitting = false
    @State private var searchText = ""

    let onFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            processList
            Divider()
            footer
        }
        .frame(width: 650, height: 620)
        .background(TaskZeroPalette.canvas)
        .foregroundStyle(TaskZeroPalette.primaryText)
        .tint(TaskZeroPalette.accent)
        .alert("Force termination can lose unsaved data", isPresented: $showingForceWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                submitCleanup()
            }
        } message: {
            Text("TaskZero always asks applications to close normally first. If an item does not respond, force termination may discard unsaved work.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Review cleanup")
                        .font(.title2.weight(.bold))
                    Text("Choose what TaskZero should close.")
                        .font(.subheadline)
                        .foregroundStyle(TaskZeroPalette.secondaryText)
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TaskZeroPalette.accentHighlight)
                    Text("\(viewModel.selectedPIDs.count) selected")
                        .foregroundStyle(TaskZeroPalette.primaryText)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(TaskZeroPalette.surface, in: Capsule())
            }
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TaskZeroPalette.secondaryText)
                TextField("Search apps and processes", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(TaskZeroPalette.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(TaskZeroPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(TaskZeroPalette.separator, lineWidth: 1))
            HStack(spacing: 8) {
                Button("Select all") { viewModel.selectAllEligible() }
                    .buttonStyle(.bordered)
                Button("Clear selection") { viewModel.deselectAllEligible() }
                    .buttonStyle(.bordered)
                Spacer()
                Label("Protected items are never targeted", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
        }
        .padding(18)
    }

    private var processList: some View {
        List {
            Section("Applications to close · \(matchingApplications.count)") {
                if !matchingApplications.isEmpty {
                    ForEach(matchingApplications) { process in
                        CleanupCandidateRow(
                            process: process,
                            isSelected: viewModel.selectedPIDs.contains(process.pid),
                            toggle: { viewModel.toggleSelection(for: process.pid) }
                        )
                    }
                } else {
                    EmptyProcessRow(text: searchText.isEmpty ? "No eligible applications" : "No matching applications")
                }
            }

            Section("Background processes to stop · \(matchingBackgroundProcesses.count)") {
                if !matchingBackgroundProcesses.isEmpty {
                    ForEach(matchingBackgroundProcesses) { process in
                        CleanupCandidateRow(
                            process: process,
                            isSelected: viewModel.selectedPIDs.contains(process.pid),
                            toggle: { viewModel.toggleSelection(for: process.pid) }
                        )
                    }
                } else {
                    EmptyProcessRow(text: searchText.isEmpty ? "No eligible background processes" : "No matching background processes")
                }
            }

            Section("Protected processes · \(matchingProtectedProcesses.count)") {
                ForEach(matchingProtectedProcesses) { process in
                    ProtectedProcessRow(process: process)
                }
            }

            Section("Excluded processes · \(matchingExcludedProcesses.count)") {
                ForEach(matchingExcludedProcesses) { process in
                    ProtectedProcessRow(process: process)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(TaskZeroPalette.canvas)
    }

    private var matchingApplications: [TaskZeroProcess] {
        (viewModel.preview?.applications ?? []).filter(matchesSearch)
    }

    private var matchingBackgroundProcesses: [TaskZeroProcess] {
        (viewModel.preview?.backgroundProcesses ?? []).filter(matchesSearch)
    }

    private var matchingProtectedProcesses: [TaskZeroProcess] {
        (viewModel.preview?.protectedProcesses ?? []).filter(matchesSearch)
    }

    private var matchingExcludedProcesses: [TaskZeroProcess] {
        (viewModel.preview?.excludedProcesses ?? []).filter(matchesSearch)
    }

    private func matchesSearch(_ process: TaskZeroProcess) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return process.displayName.localizedCaseInsensitiveContains(query)
            || process.pidLabel.localizedCaseInsensitiveContains(query)
            || process.executablePath.localizedCaseInsensitiveContains(query)
            || (process.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
    }

    private var footer: some View {
        HStack {
            if preferences.configuration.enableForceTermination {
                Label("Force termination may cause data loss", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.warning)
            } else {
                Text("Force termination is disabled")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
            Spacer()
            Button(viewModel.isCleaning ? "Stop" : "Cancel") {
                if viewModel.isCleaning {
                    viewModel.cancelCleanup()
                } else {
                    dismiss()
                }
            }
            .keyboardShortcut(.cancelAction)
            Button("Clean Now") {
                if preferences.configuration.enableForceTermination {
                    showingForceWarning = true
                } else {
                    submitCleanup()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.selectedPIDs.isEmpty || isSubmitting || viewModel.isCleaning)
        }
        .padding(14)
    }

    private func submitCleanup() {
        isSubmitting = true
        Task {
            _ = await viewModel.runCleanup()
            isSubmitting = false
            dismiss()
            onFinished()
        }
    }
}

private struct CleanupCandidateRow: View {
    let process: TaskZeroProcess
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                ProcessIcon(process: process)
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.displayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(process.pidLabel)
                        Text("·")
                        Text(process.signatureStatus.displayName)
                    }
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? TaskZeroPalette.accentHighlight : TaskZeroPalette.secondaryText)
                    .font(.title3)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}

private struct ProtectedProcessRow: View {
    let process: TaskZeroProcess

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: process.classification == .excluded ? "eye.slash" : "shield.fill")
                .foregroundStyle(TaskZeroPalette.secondaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text(process.displayName)
                    .lineLimit(1)
                Text(process.protectionReason ?? "Preserved by TaskZero safety policy")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text(process.pidLabel)
                .font(.caption.monospaced())
                .foregroundStyle(TaskZeroPalette.secondaryText)
        }
    }
}

private struct EmptyProcessRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(TaskZeroPalette.secondaryText)
    }
}

struct ProcessIcon: View {
    let process: TaskZeroProcess

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        // Prefer the running application's own icon (resolves Chrome, Slack, etc.
        // to their real artwork rather than the generic Unix-executable icon).
        if let application = NSRunningApplication(processIdentifier: process.pid),
           let applicationIcon = application.icon {
            return applicationIcon
        }

        // Fall back to the enclosing `.app` bundle, since the executable path points
        // at the Mach-O binary inside Contents/MacOS, whose icon is the generic one.
        if let bundlePath = ProcessIcon.applicationBundlePath(for: process.executablePath) {
            return NSWorkspace.shared.icon(forFile: bundlePath)
        }

        // For a plain executable with a real path, use its file icon.
        if !process.executablePath.isEmpty,
           FileManager.default.fileExists(atPath: process.executablePath) {
            return NSWorkspace.shared.icon(forFile: process.executablePath)
        }

        // Last resort: a representative SF Symbol.
        return NSImage(systemSymbolName: process.isApplication ? "app" : "gearshape", accessibilityDescription: nil)
            ?? NSImage()
    }

    private static func applicationBundlePath(for executablePath: String) -> String? {
        // Resolve the OUTERMOST `.app` bundle so that helper executables and nested
        // helper bundles (for example Chrome's `chrome_crashpad_handler` or
        // `Google Chrome Helper.app`, both buried inside
        // `Google Chrome.app/Contents/Frameworks/...`) show the top-level app's icon
        // rather than a nested helper bundle's generic icon.
        guard let appRange = executablePath.range(of: ".app/", options: [.caseInsensitive]) else {
            return nil
        }
        return String(executablePath[..<appRange.upperBound]).dropLast().description
    }
}
