import SwiftUI

struct CleanupReportView: View {
    let result: CleanupResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            summary
            Divider()
            details
            footer
        }
        .frame(width: 620, height: 560)
        .background(TaskZeroPalette.canvas)
        .foregroundStyle(TaskZeroPalette.primaryText)
        .tint(TaskZeroPalette.warmTaupe)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: result.failureCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(result.failureCount == 0 ? TaskZeroPalette.cream : TaskZeroPalette.warmTaupe)
                .frame(width: 48, height: 48)
                .background(TaskZeroPalette.cream.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(result.dryRun ? "CLEANUP PREVIEW" : "CLEANUP COMPLETE")
                    .font(.headline)
                Text("Started \(result.startedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
            Spacer()
            Text(result.duration.formattedDuration)
                .font(.subheadline.monospaced())
                .foregroundStyle(TaskZeroPalette.secondaryText)
        }
        .padding(18)
        .background(TaskZeroPalette.surface.opacity(0.7))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
            HStack(spacing: 10) {
                ReportMetric(title: "Graceful", value: result.gracefulCount, color: TaskZeroPalette.success)
                ReportMetric(title: "Force", value: result.forceTerminatedCount, color: TaskZeroPalette.warning)
                ReportMetric(title: "Could not close", value: result.failureCount, color: TaskZeroPalette.failure)
                ReportMetric(title: "Skipped", value: result.skippedCount, color: TaskZeroPalette.secondaryText)
            }
            HStack(spacing: 16) {
                Label("Protected \(result.protectedCount)", systemImage: "shield")
                Label("Excluded \(result.excludedCount)", systemImage: "eye.slash")
            }
            .font(.caption)
            .foregroundStyle(TaskZeroPalette.secondaryText)
        }
        .padding(18)
        .background(TaskZeroPalette.surface.opacity(0.42))
    }

    private var details: some View {
        List {
            Section("Applications · \(result.applications.count)") {
                ForEach(result.applications) { item in
                    CleanupResultRow(item: item)
                }
                if result.applications.isEmpty {
                    Text("No applications processed")
                        .font(.caption)
                        .foregroundStyle(TaskZeroPalette.secondaryText)
                }
            }
            Section("Background processes · \(result.backgroundProcesses.count)") {
                ForEach(result.backgroundProcesses) { item in
                    CleanupResultRow(item: item)
                }
                if result.backgroundProcesses.isEmpty {
                    Text("No background processes processed")
                        .font(.caption)
                        .foregroundStyle(TaskZeroPalette.secondaryText)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(TaskZeroPalette.canvas)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(14)
    }
}

private struct ReportMetric: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(TaskZeroPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(TaskZeroPalette.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct CleanupResultRow: View {
    let item: CleanupItemResult

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.process.displayName)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text(item.process.pidLabel)
                .font(.caption.monospaced())
                .foregroundStyle(TaskZeroPalette.secondaryText)
        }
        .padding(.vertical, 3)
    }

    private var symbol: String {
        switch item.outcome {
        case .terminatedGracefully:
            return "checkmark"
        case .forceTerminated:
            return "bolt.fill"
        case .couldNotTerminate:
            return "xmark"
        case .skipped, .dryRun:
            return "minus"
        }
    }

    private var color: Color {
        switch item.outcome {
        case .terminatedGracefully, .dryRun:
            return TaskZeroPalette.success
        case .forceTerminated:
            return TaskZeroPalette.warning
        case .couldNotTerminate:
            return TaskZeroPalette.failure
        case .skipped:
            return TaskZeroPalette.secondaryText
        }
    }
}
