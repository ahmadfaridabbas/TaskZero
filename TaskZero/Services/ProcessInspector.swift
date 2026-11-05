import Foundation
import Darwin

final class ProcessInspector: @unchecked Sendable {
    private let verifier: CodeSignatureVerifier

    init(verifier: CodeSignatureVerifier = CodeSignatureVerifier()) {
        self.verifier = verifier
    }

    /// Takes a single libproc pass over the current process table. This is inherently
    /// a point-in-time, non-atomic view: PIDs can exit or be recycled between listing
    /// and querying, and again between preview and cleanup. The identity re-checks in
    /// `identityMatches`/`signatureMatches` (path + start time + signature) guard against
    /// acting on a recycled PID, but the preview itself may briefly show stale entries.
    func snapshot() async -> [TaskZeroProcess] {
        let verifier = verifier
        return await Task.detached(priority: .utility) {
            Self.readSnapshot(verifier: verifier)
        }.value
    }

    func snapshotSynchronously() -> [TaskZeroProcess] {
        Self.readSnapshot(verifier: verifier)
    }

    func identityMatches(_ process: TaskZeroProcess) -> Bool {
        guard process.pid > 0 else { return false }

        var bsdInfo = proc_bsdinfo()
        let bsdResult = withUnsafeMutablePointer(to: &bsdInfo) { pointer in
            proc_pidinfo(
                process.pid,
                PROC_PIDTBSDINFO,
                0,
                UnsafeMutableRawPointer(pointer),
                Int32(MemoryLayout<proc_bsdinfo>.size)
            )
        }
        guard bsdResult == MemoryLayout<proc_bsdinfo>.size else { return false }

        guard let currentPath = Self.executablePath(for: process.pid), currentPath == process.executablePath else {
            return false
        }

        let currentStartTime = Date(
            timeIntervalSince1970: TimeInterval(bsdInfo.pbi_start_tvsec)
                + TimeInterval(bsdInfo.pbi_start_tvusec) / 1_000_000
        )
        if let startTime = process.startTime {
            return abs(currentStartTime.timeIntervalSince(startTime)) < 0.001
        }
        return true
    }

    func signatureMatches(_ process: TaskZeroProcess) -> Bool {
        guard identityMatches(process) else { return false }
        let signature = verifier.verify(executablePath: process.executablePath, cached: false)
        guard signature.status == process.signatureStatus else { return false }

        // Signing and team identifiers must match exactly, including the nil-vs-value
        // case: if either side changed, treat it as a different binary. For trusted
        // third-party signatures (Developer ID / ad hoc) this closes the gap where a
        // recycled PID pointing at a different signed binary would otherwise pass when
        // the originally captured identifiers were nil.
        guard signature.signingIdentifier == process.signingIdentifier else { return false }
        guard signature.teamIdentifier == process.teamIdentifier else { return false }
        return true
    }

    func isRunning(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }

    private static func readSnapshot(verifier: CodeSignatureVerifier) -> [TaskZeroProcess] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [] }

        let capacity = Int(byteCount) / MemoryLayout<pid_t>.size + 16
        var pids = [pid_t](repeating: 0, count: capacity)
        let result = pids.withUnsafeMutableBytes { bytes in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, bytes.baseAddress, Int32(bytes.count))
        }
        guard result > 0 else { return [] }

        let count = min(Int(result) / MemoryLayout<pid_t>.size, pids.count)
        let currentUserID = UInt32(getuid())
        var processes: [TaskZeroProcess] = []
        processes.reserveCapacity(count)

        for pid in pids.prefix(count) where pid > 0 {
            if let process = process(for: pid, currentUserID: currentUserID, verifier: verifier) {
                processes.append(process)
            }
        }

        return processes.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private static func process(
        for pid: pid_t,
        currentUserID: UInt32,
        verifier: CodeSignatureVerifier
    ) -> TaskZeroProcess? {
        var bsdInfo = proc_bsdinfo()
        let bsdResult = withUnsafeMutablePointer(to: &bsdInfo) { pointer in
            proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                UnsafeMutableRawPointer(pointer),
                Int32(MemoryLayout<proc_bsdinfo>.size)
            )
        }
        guard bsdResult == MemoryLayout<proc_bsdinfo>.size else { return nil }

        let executablePath = executablePath(for: pid) ?? ""
        let fallbackName = cString(from: bsdInfo.pbi_comm)
        let name = ProcessUtilities.processName(from: executablePath, fallback: fallbackName)
        let userID = UInt32(bsdInfo.pbi_uid)
        let signature: CodeSignatureInfo
        if userID == currentUserID && !ProcessUtilities.isWithinProtectedLocation(executablePath) {
            signature = verifier.verify(executablePath: executablePath)
        } else if ProcessUtilities.isWithinProtectedLocation(executablePath) {
            // Processes inside protected system locations are labelled `.appleSigned`
            // as a performance shortcut (we skip per-binary verification for the many
            // system processes). This label is NOT a cryptographic guarantee; it is
            // only ever used to KEEP such processes protected. ProcessSafetyManager
            // treats `.appleSigned` as eligible solely for regular GUI applications,
            // which never live in these locations, so a false `.appleSigned` here can
            // only make a process safer (protected), never eligible for termination.
            signature = CodeSignatureInfo(status: .appleSigned, signingIdentifier: nil, teamIdentifier: nil)
        } else {
            signature = CodeSignatureInfo(status: .unknown, signingIdentifier: nil, teamIdentifier: nil)
        }
        let startTime = Date(
            timeIntervalSince1970: TimeInterval(bsdInfo.pbi_start_tvsec)
                + TimeInterval(bsdInfo.pbi_start_tvusec) / 1_000_000
        )

        var taskInfo = proc_taskinfo()
        let taskResult = withUnsafeMutablePointer(to: &taskInfo) { pointer in
            proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                0,
                UnsafeMutableRawPointer(pointer),
                Int32(MemoryLayout<proc_taskinfo>.size)
            )
        }
        let memoryBytes: UInt64? = taskResult == MemoryLayout<proc_taskinfo>.size
            ? taskInfo.pti_resident_size
            : nil
        let cpuTimeSeconds: Double? = taskResult == MemoryLayout<proc_taskinfo>.size
            ? Double(taskInfo.pti_total_user + taskInfo.pti_total_system) / 1_000_000_000
            : nil

        return TaskZeroProcess(
            pid: Int32(pid),
            parentPID: Int32(bsdInfo.pbi_ppid),
            name: name,
            executablePath: executablePath,
            userID: userID,
            userName: ProcessUtilities.username(for: userID),
            bundleIdentifier: ProcessUtilities.applicationBundleIdentifier(for: executablePath),
            signatureStatus: signature.status,
            signingIdentifier: signature.signingIdentifier,
            teamIdentifier: signature.teamIdentifier,
            startTime: startTime,
            state: processState(for: bsdInfo.pbi_status),
            isApplication: false,
            memoryBytes: memoryBytes,
            cpuTimeSeconds: cpuTimeSeconds,
            classification: bsdInfo.pbi_uid == uid_t(currentUserID) ? .thirdParty : .protected,
            protectionReason: nil
        )
    }

    private static func executablePath(for pid: Int32) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = pathBuffer.withUnsafeMutableBytes { bytes in
            proc_pidpath(pid, bytes.baseAddress, UInt32(bytes.count))
        }
        guard length > 0 else { return nil }
        return String(cString: pathBuffer)
    }

    private static func processState(for status: UInt32) -> ProcessState {
        switch status {
        case 1:
            return .running
        case 2:
            return .sleeping
        case 3:
            return .stopped
        case 4:
            return .exiting
        default:
            return .unknown
        }
    }

    private static func cString<T>(from value: T) -> String {
        withUnsafeBytes(of: value) { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            let end = bytes.firstIndex(of: 0) ?? bytes.endIndex
            return String(decoding: bytes[..<end], as: UTF8.self)
        }
    }
}
