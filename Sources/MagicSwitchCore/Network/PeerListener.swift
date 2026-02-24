import Foundation
import Network
import Logging

/// TXT レコードのキー定数
enum TXTRecordKey {
    static let version = "version"
    static let hostId = "hostId"
    static let hostName = "hostName"
}

/// Bonjour サービス公開＋接続受付（サーバー側）
/// NWListener を使って接続を待ち受け、Bonjour でサービスを公開する
/// Blue Switch 互換: 素の TCP（NWProtocolFramer なし）、サービスタイプ `_blueswitch._tcp.`
public actor PeerListener {
    private let logger = MagicSwitchLogger.network
    private let serviceType: String
    private var listener: NWListener?
    private var port: NWEndpoint.Port?

    /// 新しい接続が確立された際のコールバック
    private var connectionHandler: (@Sendable (NWConnection) -> Void)?

    /// Blue Switch 互換サービスタイプ
    public init(serviceType: String = "_blueswitch._tcp.") {
        self.serviceType = serviceType
    }

    /// 新しい接続のハンドラを設定
    public func setConnectionHandler(_ handler: @escaping @Sendable (NWConnection) -> Void) {
        self.connectionHandler = handler
    }

    /// リスナーの開始とサービス公開
    /// Blue Switch 互換: NWProtocolFramer は使わず素の TCP
    public func startListening(
        hostName: String,
        hostId: String,
        useTLS: Bool = false
    ) async throws {
        // 既存のリスナーがあれば停止
        listener?.cancel()

        let parameters: NWParameters
        if useTLS {
            parameters = NWParameters(tls: Self.createTLSOptions())
        } else {
            parameters = NWParameters.tcp
        }

        let newListener = try NWListener(using: parameters)

        // Bonjour サービスの設定（TXT レコード付き）
        var txtRecord = NWTXTRecord()
        txtRecord[TXTRecordKey.version] = "1.0"
        txtRecord[TXTRecordKey.hostId] = hostId
        txtRecord[TXTRecordKey.hostName] = hostName

        // Blue Switch 互換: サービス名はコンピュータ名のみ（MagicSwitch- プレフィックスなし）
        newListener.service = NWListener.Service(
            name: hostName,
            type: serviceType,
            domain: nil,
            txtRecord: txtRecord
        )

        // 新しい接続のハンドラ
        let handler = self.connectionHandler
        newListener.newConnectionHandler = { connection in
            handler?(connection)
        }

        // 状態変更のハンドラ
        newListener.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            Task {
                await self.handleListenerStateChange(state)
            }
        }

        newListener.start(queue: .main)
        self.listener = newListener
        logger.info("PeerListener starting: \(hostName) (type: \(serviceType))")
    }

    /// リスナーの停止
    public func stopListening() async {
        listener?.cancel()
        listener = nil
        port = nil
        logger.info("PeerListener stopped")
    }

    /// リスナーが使用しているポートを取得
    public func getPort() -> NWEndpoint.Port? {
        port
    }

    // MARK: - Private

    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            self.port = listener?.port
            logger.info("PeerListener ready on port: \(String(describing: listener?.port))")
        case .failed(let error):
            logger.error("PeerListener failed: \(error.localizedDescription)")
        case .cancelled:
            logger.info("PeerListener cancelled")
        case .setup, .waiting:
            break
        @unknown default:
            break
        }
    }

    /// TLS オプションの作成（自己署名証明書）
    private static func createTLSOptions() -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()

        sec_protocol_options_set_min_tls_protocol_version(
            tlsOptions.securityProtocolOptions,
            .TLSv13
        )

        // TOFU (Trust on First Use) ベースの証明書検証
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, trust, completionHandler in
                let accepted = TrustedPeerStore.shared.verifyPeerCertificate(trust)
                completionHandler(accepted)
            },
            .main
        )

        return tlsOptions
    }
}
