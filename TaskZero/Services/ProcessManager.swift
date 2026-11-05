import Foundation
import Darwin

enum SignalSendResult: Equatable, Sendable {
    case sent
    case alreadyExited
    case identityChanged
    case permissionDenied
    case failed(String)
}

protocol ProcessOperating: AnyObject {
    func isRunning(_ process: TaskZeroProcess) -> Bool
    func identityMatches(_ process: TaskZeroProcess) -> Bool
    func signatureMatches(_ process: TaskZeroProcess) -> Bool
    func send(signal: Int32, to process: TaskZeroProcess) -> SignalSendResult
}

final class ProcessManager: ProcessOperating {
    private let inspector: ProcessInspector

    init(inspector: ProcessInspector) {
        self.inspector = inspector
    }

    func isRunning(_ process: TaskZeroProcess) -> Bool {
        return inspector.isRunning(pid: process.pid)
    }

    func identityMatches(_ process: TaskZeroProcess) -> Bool {
        inspector.identityMatches(process)
    }

    func signatureMatches(_ process: TaskZeroProcess) -> Bool {
        inspector.signatureMatches(process)
    }

    func send(signal: Int32, to process: TaskZeroProcess) -> SignalSendResult {
        guard identityMatches(process), signatureMatches(process) else {
            return .identityChanged
        }

        guard kill(process.pid, signal) == 0 else {
            switch errno {
            case ESRCH:
                return .alreadyExited
            case EPERM, EACCES:
                return .permissionDenied
            default:
                return .failed(String(cString: strerror(errno)))
            }
        }
        return .sent
    }
}
