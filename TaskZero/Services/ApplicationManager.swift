import AppKit
import Foundation
import Darwin

@MainActor
protocol ApplicationOperating: AnyObject {
    func discoverApplications(from snapshot: [TaskZeroProcess]) -> [TaskZeroProcess]
    func requestGracefulTermination(of process: TaskZeroProcess) -> Bool
    func forceTerminate(_ process: TaskZeroProcess) -> Bool
}

@MainActor
final class ApplicationManager: ApplicationOperating {
    private let ownProcessID: Int32
    private let verifier: CodeSignatureVerifier

    init(ownProcessID: Int32 = Int32(ProcessInfo.processInfo.processIdentifier)) {
        self.ownProcessID = ownProcessID
        self.verifier = CodeSignatureVerifier()
    }

    func discoverApplications(from snapshot: [TaskZeroProcess]) -> [TaskZeroProcess] {
        let byPID = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.pid, $0) })

        return NSWorkspace.shared.runningApplications
            .filter { application in
                application.activationPolicy == .regular
                    && application.processIdentifier != ownProcessID
                    && !application.isTerminated
            }
            .compactMap { application in
                let pid = Int32(application.processIdentifier)
                let existing = byPID[pid]
                let path = application.executableURL?.path ?? existing?.executablePath ?? ""
                let signature = existing.map {
                    CodeSignatureInfo(
                        status: $0.signatureStatus,
                        signingIdentifier: $0.signingIdentifier,
                        teamIdentifier: $0.teamIdentifier
                    )
                } ?? verifier.verify(executablePath: path)
                let name = application.localizedName
                    ?? existing?.name
                    ?? ProcessUtilities.processName(from: path, fallback: "Application")

                return TaskZeroProcess(
                    pid: pid,
                    parentPID: existing?.parentPID ?? 0,
                    name: name,
                    executablePath: path,
                    userID: existing?.userID ?? UInt32(getuid()),
                    userName: existing?.userName ?? NSUserName(),
                    bundleIdentifier: application.bundleIdentifier ?? existing?.bundleIdentifier,
                    signatureStatus: signature.status,
                    signingIdentifier: signature.signingIdentifier,
                    teamIdentifier: signature.teamIdentifier,
                    startTime: existing?.startTime,
                    state: existing?.state ?? .running,
                    isApplication: true,
                    memoryBytes: existing?.memoryBytes,
                    cpuTimeSeconds: existing?.cpuTimeSeconds,
                    classification: .application,
                    protectionReason: nil
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func requestGracefulTermination(of process: TaskZeroProcess) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: process.pid) else {
            return false
        }
        return application.terminate()
    }

    func forceTerminate(_ process: TaskZeroProcess) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: process.pid) else {
            return false
        }
        return application.forceTerminate()
    }
}
