import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

enum ExclusionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case processName
    case bundleIdentifier

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .processName:
            return "Process name"
        case .bundleIdentifier:
            return "Bundle identifier"
        }
    }
}

struct ExclusionRule: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let kind: ExclusionKind
    let value: String
    let reason: String

    init(id: UUID = UUID(), kind: ExclusionKind, value: String, reason: String? = nil) {
        self.id = id
        self.kind = kind
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? reason!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Added by you"
    }
}

struct CleanupConfiguration: Codable, Equatable, Sendable {
    /// Allowed range for graceful/force termination timeouts, in seconds.
    static let minimumTimeout: TimeInterval = 1
    static let maximumTimeout: TimeInterval = 60

    private var _gracefulTerminationTimeout: TimeInterval = 5
    private var _backgroundProcessTimeout: TimeInterval = 2

    var gracefulTerminationTimeout: TimeInterval {
        get { _gracefulTerminationTimeout }
        set { _gracefulTerminationTimeout = Self.clampTimeout(newValue) }
    }

    var backgroundProcessTimeout: TimeInterval {
        get { _backgroundProcessTimeout }
        set { _backgroundProcessTimeout = Self.clampTimeout(newValue) }
    }

    var enableForceTermination = true
    var includeBackgroundProcesses = true
    var showProcessPreview = true
    var showCleanupConfirmation = true
    var showNotifications = true
    var automaticallyDisplaySummary = true
    var launchAtLogin = false
    var startInMenuBarMode = true
    var appearance: AppearanceMode = .system

    private static func clampTimeout(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return minimumTimeout }
        return min(max(value, minimumTimeout), maximumTimeout)
    }

    private enum CodingKeys: String, CodingKey {
        case _gracefulTerminationTimeout = "gracefulTerminationTimeout"
        case _backgroundProcessTimeout = "backgroundProcessTimeout"
        case enableForceTermination
        case includeBackgroundProcesses
        case showProcessPreview
        case showCleanupConfirmation
        case showNotifications
        case automaticallyDisplaySummary
        case launchAtLogin
        case startInMenuBarMode
        case appearance
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _gracefulTerminationTimeout = Self.clampTimeout(
            try container.decodeIfPresent(TimeInterval.self, forKey: ._gracefulTerminationTimeout) ?? 5
        )
        _backgroundProcessTimeout = Self.clampTimeout(
            try container.decodeIfPresent(TimeInterval.self, forKey: ._backgroundProcessTimeout) ?? 2
        )
        enableForceTermination = try container.decodeIfPresent(Bool.self, forKey: .enableForceTermination) ?? true
        includeBackgroundProcesses = try container.decodeIfPresent(Bool.self, forKey: .includeBackgroundProcesses) ?? true
        showProcessPreview = try container.decodeIfPresent(Bool.self, forKey: .showProcessPreview) ?? true
        showCleanupConfirmation = try container.decodeIfPresent(Bool.self, forKey: .showCleanupConfirmation) ?? true
        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? true
        automaticallyDisplaySummary = try container.decodeIfPresent(Bool.self, forKey: .automaticallyDisplaySummary) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        startInMenuBarMode = try container.decodeIfPresent(Bool.self, forKey: .startInMenuBarMode) ?? true
        appearance = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_gracefulTerminationTimeout, forKey: ._gracefulTerminationTimeout)
        try container.encode(_backgroundProcessTimeout, forKey: ._backgroundProcessTimeout)
        try container.encode(enableForceTermination, forKey: .enableForceTermination)
        try container.encode(includeBackgroundProcesses, forKey: .includeBackgroundProcesses)
        try container.encode(showProcessPreview, forKey: .showProcessPreview)
        try container.encode(showCleanupConfirmation, forKey: .showCleanupConfirmation)
        try container.encode(showNotifications, forKey: .showNotifications)
        try container.encode(automaticallyDisplaySummary, forKey: .automaticallyDisplaySummary)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(startInMenuBarMode, forKey: .startInMenuBarMode)
        try container.encode(appearance, forKey: .appearance)
    }
}
