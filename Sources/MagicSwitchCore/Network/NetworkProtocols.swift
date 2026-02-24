import Foundation

/// ネットワーク上で検出されたピア情報
public struct PeerInfo: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let hostName: String
    public let hostId: String
    public let version: String
    public let endpoint: String?
    /// Bonjour サービス名（自分自身フィルタ用）
    public let serviceName: String?

    public init(
        id: UUID = UUID(),
        hostName: String,
        hostId: String,
        version: String = "1.0",
        endpoint: String? = nil,
        serviceName: String? = nil
    ) {
        self.id = id
        self.hostName = hostName
        self.hostId = hostId
        self.version = version
        self.endpoint = endpoint
        self.serviceName = serviceName
    }
}

/// ピア検出イベント
public enum PeerEvent: Sendable {
    case found(PeerInfo)
    case lost(PeerInfo)
}

/// ピア接続の状態
public enum PeerConnectionState: Sendable, Equatable {
    case idle
    case connecting
    case connected
    case disconnected
    case failed(String)
}

/// ピア検出プロトコル（テスト用に抽象化）
public protocol PeerDiscovering: Sendable {
    func startBrowsing() async -> AsyncStream<PeerEvent>
    func stopBrowsing() async
}

/// ピア通信プロトコル（Blue Switch テキストコマンド対応）
public protocol PeerCommunicating: Sendable {
    func send(_ command: DeviceCommand) async throws
    func receive() async throws -> DeviceCommand
    func getConnectionState() async -> PeerConnectionState
}

/// ネットワークマネージャの公開インターフェース
public protocol NetworkManagerProtocol: Sendable {
    func start() async throws
    func stop() async
    func sendCommand(_ command: DeviceCommand, to hostId: UUID) async throws
}
