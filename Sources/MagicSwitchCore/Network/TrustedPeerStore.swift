import Foundation
import Security
import CryptoKit
import Logging

/// Trust on First Use (TOFU) ベースのピア証明書信頼管理
/// TLS 検証ブロックからの同期アクセスが必要なため、NSLock による排他制御を使用
public final class TrustedPeerStore: @unchecked Sendable {
    public static let shared = TrustedPeerStore()

    private let logger = MagicSwitchLogger.network
    private let lock = NSLock()
    private var fingerprints: [String: String] = [:]  // identifier -> SHA-256 fingerprint
    private let storageURL: URL

    public init(baseURL: URL? = nil) {
        let base = baseURL ?? {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            return appSupport.appendingPathComponent("MagicSwitch")
        }()
        self.storageURL = base.appendingPathComponent("trusted-peers.json")
        loadFromDisk()
    }

    /// TLS 検証ブロック用のピア証明書検証 (TOFU)
    /// - 既知のフィンガープリントに一致 → 受け入れ
    /// - 未知のフィンガープリント → TOFU で受け入れ＆保存
    /// - 証明書抽出に失敗 → 拒否
    public func verifyPeerCertificate(_ trust: sec_trust_t) -> Bool {
        guard let fingerprint = extractFingerprint(from: trust) else {
            logger.warning("Failed to extract certificate fingerprint, rejecting connection")
            return false
        }

        lock.lock()
        let isKnown = fingerprints.values.contains(fingerprint)

        if isKnown {
            lock.unlock()
            logger.debug("Peer certificate verified (known fingerprint)")
            return true
        }

        // TOFU: 新しいピアのフィンガープリントを保存して受け入れ
        let id = UUID().uuidString
        fingerprints[id] = fingerprint
        let copy = fingerprints
        lock.unlock()

        logger.info("New peer certificate trusted via TOFU: \(fingerprint.prefix(20))...")
        saveToDiskAsync(copy)
        return true
    }

    /// フィンガープリントを手動で追加（ペアリング時に使用）
    public func addTrustedFingerprint(id: String, fingerprint: String) {
        lock.lock()
        fingerprints[id] = fingerprint
        let copy = fingerprints
        lock.unlock()
        saveToDiskAsync(copy)
    }

    /// フィンガープリントを削除
    public func removeTrustedFingerprint(id: String) {
        lock.lock()
        fingerprints.removeValue(forKey: id)
        let copy = fingerprints
        lock.unlock()
        saveToDiskAsync(copy)
    }

    // MARK: - Private

    private func extractFingerprint(from trust: sec_trust_t) -> String? {
        let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
        guard let certChain = SecTrustCopyCertificateChain(secTrust) else {
            return nil
        }
        guard CFArrayGetCount(certChain) > 0 else {
            return nil
        }
        let leafCert = unsafeBitCast(
            CFArrayGetValueAtIndex(certChain, 0),
            to: SecCertificate.self
        )
        let certData = SecCertificateCopyData(leafCert) as Data
        let hash = SHA256.hash(data: certData)
        return hash.map { String(format: "%02x", $0) }.joined(separator: ":")
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        lock.lock()
        fingerprints = decoded
        lock.unlock()
    }

    private func saveToDiskAsync(_ data: [String: String]) {
        let url = storageURL
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if let encoded = try? JSONEncoder().encode(data) {
                try? encoded.write(to: url, options: .atomic)
            }
        }
    }
}
