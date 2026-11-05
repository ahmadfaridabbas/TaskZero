import Foundation
import Darwin

enum ProcessUtilities {
    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func applicationBundleIdentifier(for executablePath: String) -> String? {
        guard let appRange = executablePath.range(of: ".app/", options: [.caseInsensitive, .backwards]) else {
            return nil
        }
        let bundlePath = String(executablePath[..<appRange.upperBound]).dropLast()
        return Bundle(url: URL(fileURLWithPath: String(bundlePath)))?.bundleIdentifier
    }

    static func processName(from path: String, fallback: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? fallback : name
    }

    static func isWithinProtectedLocation(_ path: String) -> Bool {
        let normalizedPath = path.lowercased()
        return TaskZeroConstants.protectedPathPrefixes.contains { prefix in
            normalizedPath.hasPrefix(prefix.lowercased())
        }
    }

    static func username(for userID: UInt32) -> String {
        guard let user = getpwuid(uid_t(userID)) else {
            return "UID \(userID)"
        }
        return String(cString: user.pointee.pw_name)
    }

    static func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
