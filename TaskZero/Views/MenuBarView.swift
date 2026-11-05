import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var viewModel: MenuBarViewModel
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingPreview = false
    @State private var showingReport = false
    @State private var showingHistory = false
    @State private var showingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            overviewCard
            metrics
            actions
            footer
        }
        .padding(18)
        .frame(width: 360)
        .background(TaskZeroPalette.canvas)
        .foregroundStyle(TaskZeroPalette.primaryText)
        .tint(TaskZeroPalette.accentHighlight)
        .task { await viewModel.refresh() }
        .sheet(isPresented: $showingPreview) {
            CleanupPreviewView {
                showingPreview = false
                if preferences.configuration.automaticallyDisplaySummary {
                    showingReport = viewModel.lastResult != nil
                }
            }
            .environmentObject(viewModel)
            .environmentObject(preferences)
        }
        .sheet(isPresented: $showingReport) {
            if let result = viewModel.lastResult { CleanupReportView(result: result) }
        }
        .sheet(isPresented: $showingHistory) {
            CleanupHistoryView().environmentObject(preferences)
        }
        .alert("Ready to clean?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean My Mac", role: .destructive) {
                Task {
                    _ = await viewModel.runCleanup()
                    if preferences.configuration.automaticallyDisplaySummary { showingReport = viewModel.lastResult != nil }
                }
            }
        } message: { Text(confirmationMessage) }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image("TaskZeroMenuBarGlyph")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .padding(10)
                .background(TaskZeroPalette.cocoa, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .foregroundStyle(TaskZeroPalette.cream)
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(TaskZeroConstants.productName).font(.headline)
                Text(TaskZeroConstants.tagline).font(.caption).foregroundStyle(TaskZeroPalette.secondaryText)
            }
            Spacer()
            Button { Task { await viewModel.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(TaskZeroPalette.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Refresh process list")
            .accessibilityLabel("Refresh process list")
            .disabled(viewModel.isRefreshing || viewModel.isCleaning)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: viewModel.isCleaning ? "arrow.triangle.2.circlepath" : "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(viewModel.isCleaning ? TaskZeroPalette.warning : TaskZeroPalette.cream)
                    .frame(width: 36, height: 36)
                    .background(TaskZeroPalette.cream.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.statusMessage).font(.subheadline.weight(.semibold))
                    Text(viewModel.lastRefreshed.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? "Private, on-device inspection")
                        .font(.caption).foregroundStyle(TaskZeroPalette.secondaryText)
                }
                Spacer(minLength: 0)
                if viewModel.isRefreshing || viewModel.isCleaning { ProgressView().controlSize(.small) }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [TaskZeroPalette.surface, TaskZeroPalette.deepBrown.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(TaskZeroPalette.separator, lineWidth: 1))
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("SYSTEM OVERVIEW")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(TaskZeroPalette.secondaryText)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                MetricTile(title: "Applications", value: viewModel.applicationCount, symbol: "macwindow", tone: TaskZeroPalette.cream)
                MetricTile(title: "Background", value: viewModel.backgroundProcessCount, symbol: "gearshape.2", tone: TaskZeroPalette.warmTaupe)
                MetricTile(title: "Protected", value: viewModel.protectedCount, symbol: "shield.lefthalf.filled", tone: TaskZeroPalette.cream.opacity(0.8))
                MetricTile(title: "Excluded", value: viewModel.excludedCount, symbol: "eye.slash", tone: TaskZeroPalette.warmTaupe)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 9) {
            Button(action: startCleanup) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Review & Clean")
                    Spacer()
                    Text("\(viewModel.eligibleCount) ready")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TaskZeroPalette.canvas)
                }
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isCleaning || viewModel.isPreparingPreview || viewModel.eligibleCount == 0)

            HStack(spacing: 9) {
                Button {
                    Task { _ = await viewModel.preparePreview(); showingPreview = true }
                } label: {
                    Label("Preview", systemImage: "list.bullet.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isCleaning || viewModel.isPreparingPreview)

                Button { openWindow(id: "process-monitor") } label: {
                    Label("Monitor", systemImage: "waveform.path.ecg").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button { showingHistory = true } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)

                Button {
                    preferences.update { $0.appearance = nextAppearance }
                } label: {
                    Label(nextAppearance == .dark ? "Dark mode" : "Light mode", systemImage: nextAppearance == .dark ? "moon.fill" : "sun.max.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .help("Switch between light and dark appearance")

                Button { NSApplication.shared.terminate(nil) } label: {
                    Label("Quit", systemImage: "power")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)
                    .help("Quit TaskZero")
            }
            HStack(spacing: 6) {
                Circle().fill(TaskZeroPalette.success).frame(width: 7, height: 7)
                Text("Your system stays in your control")
                    .font(.caption2.weight(.medium))
                Spacer()
            }
            .foregroundStyle(TaskZeroPalette.secondaryText)
            Text("MIT License • © 2026 Ahmad Farid Abbas")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(TaskZeroPalette.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 1)
    }

    private var nextAppearance: AppearanceMode {
        switch preferences.configuration.appearance {
        case .dark: return .light
        case .light: return .dark
        case .system: return colorScheme == .dark ? .light : .dark
        }
    }

    private var confirmationMessage: String {
        let selected = viewModel.selectedPIDs.count
        let forceMessage = preferences.configuration.enableForceTermination
            ? " Unresponsive items may be force terminated after the timeout, which can lose unsaved data."
            : " Force termination is disabled."
        return "TaskZero will request graceful termination for \(selected) selected item\(selected == 1 ? "" : "s").\(forceMessage)"
    }

    private func startCleanup() {
        Task {
            _ = await viewModel.preparePreview()
            if preferences.configuration.showProcessPreview { showingPreview = true }
            else if preferences.configuration.showCleanupConfirmation { showingConfirmation = true }
            else {
                _ = await viewModel.runCleanup()
                if preferences.configuration.automaticallyDisplaySummary { showingReport = viewModel.lastResult != nil }
            }
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: Int
    let symbol: String
    let tone: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 30, height: 30)
                .background(tone.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.title3.weight(.semibold).monospacedDigit())
                Text(title).font(.caption2).foregroundStyle(TaskZeroPalette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskZeroPalette.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(TaskZeroPalette.separator.opacity(0.7), lineWidth: 1))
    }
}
