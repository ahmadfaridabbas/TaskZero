import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(TaskZeroPalette.cocoa)
                Image("TaskZeroMenuBarGlyph")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(22)
                    .foregroundStyle(TaskZeroPalette.cream)
            }
            .frame(width: 96, height: 96)
            .shadow(color: TaskZeroPalette.ink.opacity(0.35), radius: 18, y: 8)
            Text(TaskZeroConstants.productName)
                .font(.title.weight(.semibold))
            Text(TaskZeroConstants.tagline)
                .foregroundStyle(TaskZeroPalette.secondaryText)
            VStack(spacing: 5) {
                Text("Version 1.0")
                Text(TaskZeroConstants.minimumSystemVersion)
                Text("Local-first process safety utility")
                Text("Released under the MIT License")
            }
            .font(.caption)
            .foregroundStyle(TaskZeroPalette.secondaryText)
            .padding(16)
            .frame(maxWidth: 420)
            .background(TaskZeroPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(TaskZeroPalette.separator, lineWidth: 1))
            Divider()
            Text("TaskZero inspects process metadata locally to identify safe, user-owned targets. It does not upload process lists, use analytics, or require administrator privileges.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(TaskZeroPalette.secondaryText)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .background(TaskZeroPalette.canvas)
        .foregroundStyle(TaskZeroPalette.primaryText)
        .tint(TaskZeroPalette.warmTaupe)
    }
}
