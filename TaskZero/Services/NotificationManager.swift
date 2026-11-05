import Foundation
import UserNotifications

final class NotificationManager: @unchecked Sendable {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func sendCleanupCompleted(_ result: CleanupResult) async {
        let content = UNMutableNotificationContent()
        content.title = "Cleanup complete"
        content.body = summary(for: result)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "taskzero.cleanup.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func summary(for result: CleanupResult) -> String {
        let successful = result.gracefulCount + result.forceTerminatedCount
        if result.failureCount > 0 {
            return "\(successful) closed, \(result.failureCount) could not be closed."
        }
        if result.forceTerminatedCount > 0 {
            return "\(successful) closed; force termination was needed for \(result.forceTerminatedCount)."
        }
        return "\(successful) process\(successful == 1 ? "" : "es") closed safely."
    }
}
