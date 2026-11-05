import SwiftUI

struct CleanupHistoryView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedResult: CleanupResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cleanup history")
                        .font(.title2.weight(.semibold))
                    Text("Stored locally on this Mac")
                        .font(.caption)
                        .foregroundStyle(TaskZeroPalette.secondaryText)
                }
                Spacer()
                Button("Clear") {
                    preferences.clearHistory()
                }
                .disabled(preferences.history.isEmpty)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(18)
            Divider()
            if preferences.history.isEmpty {
                EmptyStateView(
                    title: "No cleanup history",
                    symbol: "clock.arrow.circlepath",
                    message: "Completed cleanup summaries will appear here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(preferences.history.indices, id: \.self) { index in
                    let result = preferences.history[index]
                    Button {
                        selectedResult = result
                    } label: {
                        HistoryRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(TaskZeroPalette.canvas)
            }
        }
        .frame(width: 560, height: 470)
        .background(TaskZeroPalette.canvas)
        .foregroundStyle(TaskZeroPalette.primaryText)
        .tint(TaskZeroPalette.warmTaupe)
        .sheet(item: historySelection) { result in
            CleanupReportView(result: result)
        }
    }

    private var historySelection: Binding<CleanupResult?> {
        Binding(
            get: { selectedResult },
            set: { selectedResult = $0 }
        )
    }
}

struct EmptyStateView: View {
    let title: String
    let symbol: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(TaskZeroPalette.secondaryText)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(TaskZeroPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

private struct HistoryRow: View {
    let result: CleanupResult

    var body: some View {
        HStack {
            Image(systemName: result.failureCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(result.failureCount == 0 ? TaskZeroPalette.success : TaskZeroPalette.warning)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body.weight(.medium))
                Text("\(result.gracefulCount + result.forceTerminatedCount) closed · \(result.failureCount) failed · \(result.duration.formattedDuration)")
                    .font(.caption)
                    .foregroundStyle(TaskZeroPalette.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(TaskZeroPalette.mutedText)
        }
        .padding(12)
        .background(TaskZeroPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(TaskZeroPalette.separator.opacity(0.65), lineWidth: 1))
    }
}
