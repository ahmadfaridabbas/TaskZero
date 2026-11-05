import Foundation

enum CodeSignatureStatus: String, Codable, CaseIterable, Sendable {
    case appleSigned
    case developerID
    case adHoc
    case unsigned
    case unknown

    var displayName: String {
        switch self {
        case .appleSigned:
            return "Apple signed"
        case .developerID:
            return "Developer ID"
        case .adHoc:
            return "Ad hoc signed"
        case .unsigned:
            return "Unsigned"
        case .unknown:
            return "Unknown"
        }
    }

    var isTrustedThirdParty: Bool {
        switch self {
        case .developerID, .adHoc:
            return true
        case .appleSigned, .unsigned, .unknown:
            return false
        }
    }
}

enum ProcessClassification: String, Codable, CaseIterable, Identifiable, Sendable {
    case application
    case thirdParty
    case apple
    case protected
    case excluded
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .application:
            return "Application"
        case .thirdParty:
            return "Third party"
        case .apple:
            return "Apple"
        case .protected:
            return "Protected"
        case .excluded:
            return "Excluded"
        case .unknown:
            return "Unknown"
        }
    }
}

enum ProcessState: String, Codable, Sendable {
    case running
    case sleeping
    case stopped
    case exiting
    case unknown

    var displayName: String {
        rawValue.capitalized
    }
}

struct TaskZeroProcess: Identifiable, Codable, Hashable, Sendable {
    let pid: Int32
    let parentPID: Int32
    let name: String
    let executablePath: String
    let userID: UInt32
    let userName: String
    let bundleIdentifier: String?
    let signatureStatus: CodeSignatureStatus
    let signingIdentifier: String?
    let teamIdentifier: String?
    let startTime: Date?
    let state: ProcessState
    let isApplication: Bool
    let memoryBytes: UInt64?
    let cpuTimeSeconds: Double?
    let classification: ProcessClassification
    let protectionReason: String?

    var id: Int32 { pid }

    var displayName: String {
        name.isEmpty ? "Process \(pid)" : name
    }

    var locationDescription: String {
        executablePath.isEmpty ? "Location unavailable" : executablePath
    }

    var pidLabel: String {
        "PID \(pid)"
    }

    var memoryDescription: String {
        guard let memoryBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
    }

    var cpuTimeDescription: String {
        guard let cpuTimeSeconds else { return "—" }
        return String(format: "%.1fs", cpuTimeSeconds)
    }

    func replacing(
        classification: ProcessClassification,
        protectionReason: String? = nil,
        isApplication: Bool? = nil
    ) -> TaskZeroProcess {
        TaskZeroProcess(
            pid: pid,
            parentPID: parentPID,
            name: name,
            executablePath: executablePath,
            userID: userID,
            userName: userName,
            bundleIdentifier: bundleIdentifier,
            signatureStatus: signatureStatus,
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier,
            startTime: startTime,
            state: state,
            isApplication: isApplication ?? self.isApplication,
            memoryBytes: memoryBytes,
            cpuTimeSeconds: cpuTimeSeconds,
            classification: classification,
            protectionReason: protectionReason
        )
    }
}

enum SafetyDecision: Equatable, Sendable {
    case eligible
    case protected(reason: String)
    case excluded(reason: String)
}

struct CodeSignatureInfo: Equatable, Sendable {
    let status: CodeSignatureStatus
    let signingIdentifier: String?
    let teamIdentifier: String?
}
