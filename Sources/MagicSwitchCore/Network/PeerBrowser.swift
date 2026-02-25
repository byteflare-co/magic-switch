import Foundation
import Network
import Logging

/// Bonjour サービス検出
/// NWBrowser を使ってローカルネットワーク上の Blue Switch / Magic Switch インスタンスを検出する
public actor PeerBrowser: PeerDiscovering {
    private let logger = MagicSwitchLogger.network
    private let serviceType: String
    private var browser: NWBrowser?
    private var discoveredPeers: [NWEndpoint: PeerInfo] = [:]

    /// Magic Switch サービスタイプ
    public init(serviceType: String = "_magicswitch._tcp.") {
        self.serviceType = serviceType
    }

    /// Bonjour ブラウジングの開始
    public func startBrowsing() async -> AsyncStream<PeerEvent> {
        // 既存のブラウザがあれば停止
        browser?.cancel()

        let svcType = self.serviceType

        return AsyncStream { continuation in
            let params = NWParameters()
            params.includePeerToPeer = true

            let newBrowser = NWBrowser(
                for: .bonjour(type: svcType, domain: nil),
                using: params
            )

            newBrowser.browseResultsChangedHandler = { results, changes in
                let logger = MagicSwitchLogger.network
                for change in changes {
                    switch change {
                    case .added(let result):
                        let peerInfo = Self.extractPeerInfo(from: result)
                        logger.debug("PeerBrowser: .added '\(peerInfo.hostName)' hostId=\(peerInfo.hostId) resolved=\(peerInfo.hasResolvedHostId) svc=\(peerInfo.serviceName ?? "nil")")
                        continuation.yield(.found(peerInfo))
                    case .removed(let result):
                        let peerInfo = Self.extractPeerInfo(from: result)
                        logger.debug("PeerBrowser: .removed '\(peerInfo.hostName)' hostId=\(peerInfo.hostId) svc=\(peerInfo.serviceName ?? "nil")")
                        continuation.yield(.lost(peerInfo))
                    case .changed(old: _, new: let newResult, flags: _):
                        let peerInfo = Self.extractPeerInfo(from: newResult)
                        logger.debug("PeerBrowser: .changed '\(peerInfo.hostName)' hostId=\(peerInfo.hostId) resolved=\(peerInfo.hasResolvedHostId) svc=\(peerInfo.serviceName ?? "nil")")
                        continuation.yield(.found(peerInfo))
                    case .identical:
                        break
                    @unknown default:
                        break
                    }
                }
            }

            newBrowser.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    break
                case .failed:
                    break
                case .cancelled:
                    continuation.finish()
                default:
                    break
                }
            }

            continuation.onTermination = { @Sendable _ in
                newBrowser.cancel()
            }

            newBrowser.start(queue: .main)

            Task { [weak self] in
                await self?.setBrowser(newBrowser)
            }
        }
    }

    /// ブラウジングの停止
    public func stopBrowsing() async {
        browser?.cancel()
        browser = nil
        discoveredPeers.removeAll()
        logger.info("Peer browsing stopped")
    }

    /// 現在検出されているピアの一覧
    public func getDiscoveredPeers() -> [PeerInfo] {
        Array(discoveredPeers.values)
    }

    // MARK: - Private

    private func setBrowser(_ newBrowser: NWBrowser) {
        self.browser = newBrowser
    }

    /// NWBrowser.Result から PeerInfo を抽出
    /// Blue Switch 互換: サービス名はコンピュータ名をそのまま使用
    private static func extractPeerInfo(from result: NWBrowser.Result) -> PeerInfo {
        let logger = MagicSwitchLogger.network
        var hostName = "Unknown"
        var hostId = UUID().uuidString
        var hasResolvedHostId = false
        var version = "1.0"
        var serviceName: String?

        // サービス名からホスト名を取得
        // Blue Switch 互換: サービス名 = コンピュータ名（MagicSwitch- プレフィックスなし）
        if case .service(let name, _, _, _) = result.endpoint {
            serviceName = name
            hostName = name
        }

        // TXT レコードからメタデータを取得（Magic Switch 拡張）
        if case .bonjour(let txtRecord) = result.metadata {
            if let value = txtRecord["hostId"] {
                hostId = value
                hasResolvedHostId = true
            }
            if let value = txtRecord["hostName"] {
                hostName = value
            }
            if let value = txtRecord["version"] {
                version = value
            }
        }

        if !hasResolvedHostId {
            logger.debug("PeerBrowser: hostId not in TXT record, using placeholder for '\(hostName)'")
        }

        let endpointDescription: String?
        switch result.endpoint {
        case .service(let name, let type, let domain, _):
            endpointDescription = "\(name).\(type)\(domain)"
        default:
            endpointDescription = nil
        }

        return PeerInfo(
            hostName: hostName,
            hostId: hostId,
            hasResolvedHostId: hasResolvedHostId,
            version: version,
            endpoint: endpointDescription,
            serviceName: serviceName
        )
    }
}
