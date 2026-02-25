import Foundation
import IOKit
import Network
import Logging
import SystemConfiguration

/// Mac 間ネットワーク通信の統合管理
/// PeerBrowser（検出）、PeerListener（受信）、PeerConnection（送受信）を統合管理する
/// Blue Switch 互換: サービスタイプ `_magicswitch._tcp.`、テキストベースコマンド
public actor NetworkManager: NetworkManagerProtocol {
    private let logger = MagicSwitchLogger.network
    private let serviceType = "_magicswitch._tcp."

    // サブコンポーネント
    private let browser: PeerBrowser
    private let listener: PeerListener

    // 接続管理
    private var connections: [UUID: PeerConnection] = [:]
    private var peerMap: [String: UUID] = [:]  // hostId (String) -> UUID

    // 検出されたピア
    private var discoveredPeers: [String: PeerInfo] = [:]  // hostId -> PeerInfo

    // ハートビートタスク
    private var heartbeatTask: Task<Void, Never>?

    // 受信メッセージハンドラ
    private var messageHandler: (@Sendable (DeviceCommand, UUID) async -> Void)?

    // ホスト情報
    private var hostName: String?
    private var hostId: String?
    /// Bonjour サービス名（自分自身フィルタ用）
    private var ownServiceName: String?
    /// ローカルホスト名（古い Bonjour キャッシュのフィルタ用）
    private var localHostName: String?

    public init() {
        self.browser = PeerBrowser()
        self.listener = PeerListener()
    }

    /// テスト用イニシャライザ
    init(browser: PeerBrowser, listener: PeerListener) {
        self.browser = browser
        self.listener = listener
    }

    // MARK: - Public API

    /// ネットワークサービスの開始（サーバー兼クライアント）
    public func start(hostName: String, hostId: String) async throws {
        self.hostName = hostName
        self.hostId = hostId
        // Blue Switch 互換: サービス名はコンピュータ名のみ
        self.ownServiceName = hostName
        // DNS ローカルホスト名も保持（古い Bonjour キャッシュのフィルタ用）
        self.localHostName = SCDynamicStoreCopyLocalHostName(nil) as String?

        // リスナーの開始（サービス公開 + 接続受付）
        await listener.setConnectionHandler { [weak self] connection in
            guard let self = self else { return }
            Task {
                await self.handleIncomingConnection(connection)
            }
        }
        try await listener.startListening(
            hostName: hostName,
            hostId: hostId
        )

        // ブラウザの開始（ピア検出）
        let events = await browser.startBrowsing()
        Task { [weak self] in
            for await event in events {
                await self?.handlePeerEvent(event)
            }
        }

        // ハートビートの開始（HEALTH_CHECK コマンドで代用）
        startHeartbeat()

        logger.info("NetworkManager started: \(hostName) (\(hostId))")
    }

    /// NetworkManagerProtocol 準拠の start()
    public func start() async throws {
        // SCDynamicStoreCopyComputerName でユーザーが設定したコンピュータ名を取得
        let name = Self.computerName()
        // ハードウェア UUID を使うことで、起動のたびに変わらない安定した ID にする
        let id = stableHostId()
        try await start(hostName: name, hostId: id)
    }

    /// macOS のシステム環境設定 > 一般 > 共有 で設定されたコンピュータ名を取得
    private static func computerName() -> String {
        let rawName: String
        if let name = SCDynamicStoreCopyComputerName(nil, nil) as String?, !name.isEmpty {
            rawName = name
        } else if let name = SCDynamicStoreCopyLocalHostName(nil) as String?, !name.isEmpty {
            rawName = name
        } else {
            rawName = ProcessInfo.processInfo.hostName
        }

        // シリアル番号のようなランダム文字列だけの場合、モデル名を付加
        let friendlyKeywords = ["Mac", "iMac", "MacBook", "の"]
        if friendlyKeywords.contains(where: { rawName.contains($0) }) {
            return rawName
        }
        if let model = macModelName() {
            return "\(model) (\(rawName))"
        }
        return rawName
    }

    /// Mac のモデル名を取得
    private static func macModelName() -> String? {
        var size: size_t = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let identifier = String(cString: model)

        if identifier.hasPrefix("MacBookPro") { return "MacBook Pro" }
        if identifier.hasPrefix("MacBookAir") { return "MacBook Air" }
        if identifier.hasPrefix("Macmini") || identifier.hasPrefix("Mac14,12") { return "Mac mini" }
        if identifier.hasPrefix("MacPro") { return "Mac Pro" }
        if identifier.hasPrefix("iMac") { return "iMac" }
        if identifier.hasPrefix("Mac1") || identifier.hasPrefix("Mac16") { return "Mac" }
        return identifier
    }

    /// Mac 固有の安定した ID を取得（IOPlatformUUID）
    private func stableHostId() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return UUID().uuidString }
        defer { IOObjectRelease(platformExpert) }

        if let uuidCF = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return uuidCF
        }
        return UUID().uuidString
    }

    /// 検出されたピアが自分自身かどうか判定
    private func isSelf(_ peer: PeerInfo) -> Bool {
        // 1. hostId (IOPlatformUUID) exact match — definitive
        if let myId = self.hostId, peer.hostId == myId {
            return true
        }
        // 2. Both have resolved hostIds that differ → definitely NOT self
        if peer.hasResolvedHostId, self.hostId != nil {
            return false
        }
        // 3-5. Name-based fallback (Blue Switch compatibility only)
        if let own = self.ownServiceName,
           let svc = peer.serviceName,
           svc.hasPrefix(own) {
            return true
        }
        if let myName = self.hostName, peer.hostName.hasPrefix(myName) {
            return true
        }
        if let local = self.localHostName, peer.hostName.hasPrefix(local) {
            return true
        }
        return false
    }

    /// ネットワークサービスの停止
    public func stop() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil

        for (_, connection) in connections {
            await connection.stop()
        }
        connections.removeAll()
        peerMap.removeAll()
        discoveredPeers.removeAll()

        await browser.stopBrowsing()
        await listener.stopListening()

        logger.info("NetworkManager stopped")
    }

    /// 受信メッセージのハンドラを設定
    public func setMessageHandler(
        _ handler: @escaping @Sendable (DeviceCommand, UUID) async -> Void
    ) {
        self.messageHandler = handler
    }

    /// コマンドの送信
    public func sendCommand(_ command: DeviceCommand, to hostId: UUID) async throws {
        guard let connection = connections[hostId] else {
            throw MagicSwitchError.peerNotFound(hostId: hostId)
        }
        try await connection.send(command)
    }

    /// コマンドの送信（hostId を String で指定）
    public func sendCommand(_ command: DeviceCommand, toHostId hostId: String) async throws {
        guard let uuid = peerMap[hostId],
              let connection = connections[uuid] else {
            throw MagicSwitchError.peerNotFound(hostId: UUID())
        }
        try await connection.send(command)
    }

    /// コマンドの送信（peerHostId で接続先を特定、未接続なら自動接続）
    public func sendCommandToPeer(_ command: DeviceCommand, peerHostId: String) async throws {
        // 1. 既存の接続を peerMap から検索
        if let uuid = peerMap[peerHostId],
           let connection = connections[uuid] {
            try await connection.send(command)
            return
        }

        // 2. discoveredPeers から該当ピアを探して自動接続
        guard let peerInfo = discoveredPeers[peerHostId] else {
            throw MagicSwitchError.peerNotFound(hostId: UUID())
        }

        try await connectToPeer(peerInfo)

        guard let uuid = peerMap[peerHostId],
              let connection = connections[uuid] else {
            throw MagicSwitchError.peerNotFound(hostId: UUID())
        }
        try await connection.send(command)
    }

    /// ピアがオンラインかどうか確認
    public func isPeerOnline(_ hostId: UUID) -> Bool {
        connections[hostId] != nil
    }

    /// 検出されたピアの一覧を取得
    public func getDiscoveredPeers() -> [PeerInfo] {
        Array(discoveredPeers.values)
    }

    /// 特定ピアへの接続を取得
    public func getConnection(for hostId: UUID) -> PeerConnection? {
        connections[hostId]
    }

    // MARK: - Peer Event Handling

    private func handlePeerEvent(_ event: PeerEvent) {
        switch event {
        case .found(let peerInfo):
            if isSelf(peerInfo) {
                logger.debug("Ignoring self: \(peerInfo.hostName)")
                return
            }
            // Deduplicate: remove stale entries with the same serviceName but different hostId
            if let svcName = peerInfo.serviceName {
                let staleKeys = discoveredPeers
                    .filter { $0.value.serviceName == svcName && $0.key != peerInfo.hostId }
                    .map(\.key)
                for key in staleKeys {
                    logger.debug("Removing stale peer entry: hostId=\(key) (replaced by \(peerInfo.hostId))")
                    discoveredPeers.removeValue(forKey: key)
                }
            }
            discoveredPeers[peerInfo.hostId] = peerInfo
            logger.info("Peer discovered: \(peerInfo.hostName) (\(peerInfo.hostId)) resolved=\(peerInfo.hasResolvedHostId)")

        case .lost(let peerInfo):
            discoveredPeers.removeValue(forKey: peerInfo.hostId)
            // Also clean up by serviceName in case hostId changed since entry was added
            if let svcName = peerInfo.serviceName {
                let matchingKeys = discoveredPeers
                    .filter { $0.value.serviceName == svcName }
                    .map(\.key)
                for key in matchingKeys {
                    logger.debug("Cleaning up peer by serviceName: hostId=\(key) svc=\(svcName)")
                    discoveredPeers.removeValue(forKey: key)
                }
            }
            logger.info("Peer lost: \(peerInfo.hostName) (\(peerInfo.hostId))")
        }
    }

    // MARK: - Connection Management

    /// 検出されたピアへの接続
    /// Blue Switch 互換: サービス名はコンピュータ名のみ
    public func connectToPeer(_ peerInfo: PeerInfo) async throws {
        guard peerInfo.endpoint != nil else {
            throw MagicSwitchError.peerUnreachable(hostId: peerInfo.id)
        }

        let connection = PeerConnection(
            to: NWEndpoint.service(
                name: peerInfo.hostName,
                type: serviceType,
                domain: "local.",
                interface: nil
            )
        )

        try await connection.start()

        let peerId = peerInfo.id
        await connection.setReceiveHandler { [weak self] command in
            guard let self = self else { return }
            Task {
                await self.handleReceivedCommand(command, from: peerId)
            }
        }

        connections[peerInfo.id] = connection
        peerMap[peerInfo.hostId] = peerInfo.id
        logger.info("Connected to peer: \(peerInfo.hostName)")
    }

    /// 受信接続のハンドリング
    private func handleIncomingConnection(_ nwConnection: NWConnection) {
        let connection = PeerConnection(connection: nwConnection)
        let connectionId = UUID()

        Task {
            do {
                try await connection.start()

                await connection.setReceiveHandler { [weak self] command in
                    guard let self = self else { return }
                    Task {
                        await self.handleReceivedCommand(command, from: connectionId)
                    }
                }

                self.connections[connectionId] = connection
                logger.info("Accepted incoming connection: \(nwConnection.endpoint)")
            } catch {
                logger.error("Failed to accept connection: \(error.localizedDescription)")
            }
        }
    }

    /// 受信コマンドのハンドリング
    private func handleReceivedCommand(_ command: DeviceCommand, from peerId: UUID) {
        logger.debug("Received command from \(peerId): \(command.rawValue)")

        Task {
            await messageHandler?(command, peerId)
        }
    }

    // MARK: - Heartbeat

    /// ヘルスチェックの定期送信（30秒間隔）
    /// Blue Switch の HEALTH_CHECK コマンドを使用
    private func startHeartbeat() {
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self = self else { return }

                let currentConnections = await self.connections
                for (_, connection) in currentConnections {
                    try? await connection.send(.healthCheck)
                }
            }
        }
    }
}
