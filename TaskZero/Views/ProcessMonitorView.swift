import SwiftUI

struct ProcessMonitorView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var viewModel = ProcessMonitorViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if viewModel.isLoading && viewModel.processes.isEmpty {
                ProgressView("Inspecting processes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredProcesses.isEmpty {
                EmptyStateView(
                    title: "No matching processes",
                    symbol: "line.3.horizontal.decrease.circle",
                    message: "Try another filter or search term."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                processList
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .background(TaskZeroPalette.canvas)
        .foregroundStyle(TaskZeroPalette.primaryText)
        .tint(TaskZeroPalette.warmTaupe)
        .task {
            viewModel.updateExclusions(preferences.exclusions)
            await viewModel.refresh()
        }
        .onChange(of: preferences.exclusions) { exclusions in
            viewModel.updateExclusions(exclusions)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 11) {
                    Image("TaskZeroMenuBarGlyph")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 21, height: 21)
                        .foregroundStyle(TaskZeroPalette.cream)
                        .frame(width: 40, height: 40)
                        .background(TaskZeroPalette.cocoa, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Process monitor").font(.title2.weight(.bold))
                        Text("A live, read-only view of running processes")
                            .font(.caption).foregroundStyle(TaskZeroPalette.secondaryText)
                    }
                }
                Spacer()
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            HStack(spacing: 7) {
                Image(systemName: "lock.shield.fill").foregroundStyle(TaskZeroPalette.cream)
                Text("Inspection only · nothing is terminated from this screen")
                    .foregroundStyle(TaskZeroPalette.primaryText)
                Spacer()
                Text("\(viewModel.filteredProcesses.count) shown")
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(TaskZeroPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(TaskZeroPalette.separator, lineWidth: 1))
            HStack(spacing: 12) {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(ProcessMonitorFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .frame(width: 220)
                TextField("Search name or PID", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                Spacer()
            }
        }
        .padding(20)
    }

    private var processList: some View {
        List(viewModel.filteredProcesses) { process in
            ProcessMonitorRow(process: process)
                .listRowBackground(TaskZeroPalette.surface)
                .listRowSeparatorTint(TaskZeroPalette.separator)
                .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                .contextMenu {
                    Button("Exclude process name “\(process.displayName)”") {
                        preferences.addExclusion(kind: .processName, value: process.name, reason: "Added from Process Monitor")
                    }
                    if let bundleIdentifier = process.bundleIdentifier {
                        Button("Exclude bundle “\(bundleIdentifier)”") {
                            preferences.addExclusion(kind: .bundleIdentifier, value: bundleIdentifier, reason: "Added from Process Monitor")
                        }
                    }
                }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(TaskZeroPalette.canvas)
    }
}

private struct ProcessMonitorRow: View {
    let process: TaskZeroProcess

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 7) {
                DetailLine(label: "Executable", value: process.locationDescription)
                DetailLine(label: "Parent PID", value: "\(process.parentPID)")
                DetailLine(label: "User", value: "\(process.userName) (\(process.userID))")
                DetailLine(label: "Bundle ID", value: process.bundleIdentifier ?? "Unavailable")
                DetailLine(label: "Signature", value: process.signatureStatus.displayName)
                DetailLine(label: "Team ID", value: process.teamIdentifier ?? "Unavailable")
                if let reason = process.protectionReason {
                    DetailLine(label: "Policy", value: reason)
                }
            }
            .padding(12)
            .background(TaskZeroPalette.deepBrown.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 20)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.displayName)
                        .font(.body.weight(.medium))
                    Text(process.pidLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(TaskZeroPalette.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(process.memoryDescription)
                    Text(process.cpuTimeDescription)
                        .font(.caption)
                        .foregroundStyle(TaskZeroPalette.secondaryText)
                }
                .font(.caption.monospaced())
                Text(process.classification.displayName)
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
                    .frame(width: 110, alignment: .trailing)
            }
        }
    }

    private var symbol: String {
        switch process.classification {
        case .application:
            return "app"
        case .thirdParty:
            return "gearshape.2"
        case .apple:
            return "apple.logo"
        case .protected:
            return "shield"
        case .excluded:
            return "eye.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var color: Color {
        switch process.classification {
        case .application, .thirdParty:
            return TaskZeroPalette.accentHighlight
        case .apple:
            return TaskZeroPalette.secondaryText
        case .protected:
            return TaskZeroPalette.warning
        case .excluded:
            return TaskZeroPalette.warmTaupe
        case .unknown:
            return TaskZeroPalette.mutedText
        }
    }
}

private struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption.weight(.medium))
                    .foregroundStyle(TaskZeroPalette.secondaryText)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
