import Foundation
import Logging

/// BluetoothManager と NetworkManager を組み合わせたデバイス検出サービス
public actor DeviceDiscoveryService {
    private let logger = MagicSwitchLogger.switching
    private let bluetooth: BluetoothManager
    private let network: NetworkManager
    private let configStore: ConfigStore

    /// デバイス検出結果
    public struct DiscoveryResult: Sendable {
        public let devices: [MagicDevice]
        public let hosts: [HostMac]
        public let peers: [PeerInfo]
    }

    public init(
        bluetooth: BluetoothManager,
        network: NetworkManager,
        configStore: ConfigStore
    ) {
        self.bluetooth = bluetooth
        self.network = network
        self.configStore = configStore
    }

    /// ペアリング済み Magic デバイスを検出
    public func discoverDevices() async -> [MagicDevice] {
        logger.info("Starting device discovery...")
        let devices = await bluetooth.discoverMagicDevices()
        logger.info("Found \(devices.count) Magic device(s)")
        return devices
    }

    /// ネットワーク上の Magic Switch インスタンス（Mac）を検出
    public func discoverPeers() async -> [PeerInfo] {
        logger.info("Starting peer discovery...")
        let peers = await network.getDiscoveredPeers()
        logger.info("Found \(peers.count) peer(s)")
        return peers
    }

    /// 登録済みホストの状態を更新
    public func refreshHostStatus() async -> [HostMac] {
        let hosts: [HostMac] = await configStore.loadOrDefault(
            [HostMac].self,
            from: "hosts.json",
            default: []
        )
        let peers = await network.getDiscoveredPeers()

        return hosts.map { host in
            var updated = host
            if let peerHostId = host.peerHostId {
                updated.isOnline = peers.contains { $0.hostId == peerHostId }
            } else {
                // レガシーホスト: hostName でフォールバックマッチ
                updated.isOnline = peers.contains { $0.hostName == host.hostName }
            }
            if updated.isOnline {
                updated.lastSeen = Date()
            }
            return updated
        }
    }

    /// デバイスとピアの一括検出
    public func discoverAll() async -> DiscoveryResult {
        async let devices = discoverDevices()
        async let peers = discoverPeers()
        async let hosts = refreshHostStatus()

        return await DiscoveryResult(
            devices: devices,
            hosts: hosts,
            peers: peers
        )
    }
}
