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
        logger.debug("refreshHostStatus: \(hosts.count) host(s), \(peers.count) peer(s)")

        var needsSave = false
        let updatedHosts = hosts.map { host -> HostMac in
            var updated = host
            // Primary match: peerHostId exact match
            if let peerHostId = host.peerHostId,
               peers.contains(where: { $0.hostId == peerHostId }) {
                updated.isOnline = true
                logger.debug("Host '\(host.hostName)' matched by peerHostId")
            } else if let matched = peers.first(where: { $0.hostName == host.hostName }) {
                // Fallback: hostName match + auto-repair peerHostId
                updated.isOnline = true
                if updated.peerHostId != matched.hostId {
                    logger.info("Auto-repairing peerHostId for '\(host.hostName)': \(host.peerHostId ?? "nil") → \(matched.hostId)")
                    updated.peerHostId = matched.hostId
                    needsSave = true
                }
                logger.debug("Host '\(host.hostName)' matched by hostName fallback")
            } else {
                updated.isOnline = false
                logger.debug("Host '\(host.hostName)' not found in peers (peerHostId=\(host.peerHostId ?? "nil"))")
            }
            if updated.isOnline {
                updated.lastSeen = Date()
            }
            return updated
        }

        // Auto-repair: save updated peerHostIds so future matches work immediately
        if needsSave {
            do {
                try await configStore.save(updatedHosts, to: "hosts.json")
                logger.info("Saved auto-repaired host config")
            } catch {
                logger.error("Failed to save auto-repaired host config: \(error.localizedDescription)")
            }
        }

        return updatedHosts
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
