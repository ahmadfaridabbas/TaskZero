import Foundation

struct ProcessClassifier: Sendable {
    func baseClassification(for process: TaskZeroProcess) -> ProcessClassification {
        if process.signatureStatus == .appleSigned || ProcessUtilities.isWithinProtectedLocation(process.executablePath) {
            return .apple
        }
        if process.isApplication {
            return .application
        }
        if process.signatureStatus.isTrustedThirdParty {
            return .thirdParty
        }
        return .unknown
    }
}
