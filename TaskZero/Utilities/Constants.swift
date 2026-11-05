import Foundation
import SwiftUI
import AppKit

enum TaskZeroPalette {
    // Neutral graphite palette, adapted to the selected macOS appearance.
    static let ink = adaptive(light: 0x202327, dark: 0xF1F2F3)
    static let deepBrown = adaptive(light: 0xFFFFFF, dark: 0x202327)
    static let cocoa = adaptive(light: 0xE7E9EB, dark: 0x2B2F34)
    static let warmTaupe = adaptive(light: 0x434A52, dark: 0xC7CDD3)
    static let cream = adaptive(light: 0x202327, dark: 0xF1F2F3)

    static let canvas = adaptive(light: 0xF3F4F5, dark: 0x151719)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x202327)
    static let primaryText = adaptive(light: 0x202327, dark: 0xF1F2F3)
    static let secondaryText = adaptive(light: 0x62686E, dark: 0xA6ABB0)
    static let mutedText = adaptive(light: 0x858B91, dark: 0x777D83)
    static let accent = adaptive(light: 0x41474D, dark: 0xC7CDD3)
    static let accentHighlight = adaptive(light: 0x343A40, dark: 0xE0E3E6)
    static let success = adaptive(light: 0x287B58, dark: 0x45C77A)
    static let warning = adaptive(light: 0x8A6F46, dark: 0xD0B78F)
    static let failure = adaptive(light: 0x914F4F, dark: 0xD69A9A)
    static let separator = adaptive(light: 0xD7DADD, dark: 0x3B4045)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum TaskZeroConstants {
    static let bundleIdentifier = "net.ahmadfaridabbas.TaskZero"
    static let productName = "TaskZero"
    static let tagline = "One click. Zero clutter."
    static let minimumSystemVersion = "macOS 13.0 or later"
    static let historyLimit = 20
    static let preferencesKey = "taskzero.preferences"
    static let historyKey = "taskzero.cleanup-history"
    static let notificationCategory = "TASKZERO_CLEANUP"

    static let protectedProcessNames: Set<String> = [
        "launchd",
        "kernel_task",
        "kernelmanagerd",
        "WindowServer",
        "loginwindow",
        "Finder",
        "Dock",
        "SystemUIServer",
        "ControlCenter",
        "NotificationCenter",
        "UserEventAgent",
        "runningboardd",
        "trustd",
        "securityd",
        "coreservicesd",
        "lsd",
        "cfprefsd",
        "distnoted",
        "opendirectoryd",
        "notifyd",
        "configd",
        "mDNSResponder",
        "networkserviceproxy",
        "nesessionmanager",
        "airportd",
        "sharingd",
        "coreaudiod",
        "audioaccessoryd",
        "bluetoothd",
        "usbd",
        "diskarbitrationd",
        "powerd",
        "logd",
        "syslogd",
        "mds",
        "mdworker",
        "fseventsd",
        "backupd",
        "screencaptureui"
    ]

    static let protectedPathPrefixes = [
        "/System/",
        "/usr/libexec/",
        "/usr/sbin/",
        "/sbin/",
        "/bin/",
        "/usr/bin/",
        "/library/apple/",
        "/private/system/",
        "/private/usr/",
        "/private/etc/",
        "/private/var/db/",
        "/private/var/run/"
    ]
}

extension TimeInterval {
    var formattedDuration: String {
        if self < 1 {
            return "Less than a second"
        }
        if self < 60 {
            return String(format: "%.1f seconds", self)
        }
        return String(format: "%.0f seconds", self)
    }
}
