import Foundation
import Security

final class CodeSignatureVerifier: @unchecked Sendable {
    private struct CacheKey: Hashable {
        let path: String
        let modified: TimeInterval
        let size: Int64
    }

    private let cacheLock = NSLock()
    private var cache: [CacheKey: CodeSignatureInfo] = [:]
    private var insertionOrder: [CacheKey] = []
    private let maximumEntries = 512

    func verify(executablePath: String, cached: Bool = true) -> CodeSignatureInfo {
        let key = cached ? cacheKey(for: executablePath) : nil

        if let key {
            cacheLock.lock()
            let cachedResult = cache[key]
            cacheLock.unlock()
            if let cachedResult {
                return cachedResult
            }
        }

        let result = verifyUncached(executablePath: executablePath)

        if let key {
            cacheLock.lock()
            if cache[key] == nil {
                cache[key] = result
                insertionOrder.append(key)
                if insertionOrder.count > maximumEntries {
                    let evicted = insertionOrder.removeFirst()
                    cache.removeValue(forKey: evicted)
                }
            }
            cacheLock.unlock()
        }
        return result
    }

    /// Builds a cache key that incorporates the file's modification date and size so a
    /// binary replaced in place (for example an in-place app update) is re-verified
    /// rather than returning a stale signature classification.
    private func cacheKey(for executablePath: String) -> CacheKey? {
        guard !executablePath.isEmpty else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: executablePath)
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        return CacheKey(path: executablePath, modified: modified, size: size)
    }

    private func verifyUncached(executablePath: String) -> CodeSignatureInfo {
        guard !executablePath.isEmpty,
              FileManager.default.isReadableFile(atPath: executablePath)
        else {
            return CodeSignatureInfo(status: .unknown, signingIdentifier: nil, teamIdentifier: nil)
        }

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            URL(fileURLWithPath: executablePath) as CFURL,
            SecCSFlags(),
            &staticCode
        )
        guard createStatus == errSecSuccess, let staticCode else {
            return CodeSignatureInfo(
                status: createStatus == errSecCSUnsigned ? .unsigned : .unknown,
                signingIdentifier: nil,
                teamIdentifier: nil
            )
        }

        let validityStatus = SecStaticCodeCheckValidity(staticCode, SecCSFlags(), nil)
        guard validityStatus == errSecSuccess else {
            return CodeSignatureInfo(
                status: validityStatus == errSecCSUnsigned ? .unsigned : .unknown,
                signingIdentifier: nil,
                teamIdentifier: nil
            )
        }

        var signingInformation: CFDictionary?
        let informationStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInformation
        )

        var signingIdentifier: String?
        var teamIdentifier: String?
        if informationStatus == errSecSuccess,
           let dictionary = signingInformation as? [String: Any]
        {
            signingIdentifier = dictionary[kSecCodeInfoIdentifier as String] as? String
            teamIdentifier = dictionary[kSecCodeInfoTeamIdentifier as String] as? String
        }

        let normalizedPath = executablePath.lowercased()
        let isApplePath = normalizedPath.hasPrefix("/system/")
            || normalizedPath.hasPrefix("/usr/libexec/")
            || normalizedPath.hasPrefix("/usr/sbin/")
            || normalizedPath.hasPrefix("/sbin/")
            || normalizedPath.hasPrefix("/bin/")
            || normalizedPath.hasPrefix("/usr/bin/")
        let isAppleIdentifier = signingIdentifier?.lowercased().hasPrefix("com.apple.") == true

        return CodeSignatureInfo(
            status: isApplePath || isAppleIdentifier ? .appleSigned : .developerID,
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier
        )
    }
}
