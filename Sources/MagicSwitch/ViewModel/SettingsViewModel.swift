import Foundation
import MagicSwitchCore

/// 設定画面 ViewModel
@MainActor
public final class SettingsViewModel: ObservableObject {
    // General
    @Published public var config: AppConfig = AppConfig()

    // Devices
    @Published public var devices: [MagicDevice] = []
    @Published public var isDiscoveringDevices = false

    // Hosts
    @Published public var hosts: [HostMac] = []
    @Published public var peers: [PeerInfo] = []
    @Published public var isDiscoveringPeers = false

    // Status
    @Published public var errorMessage: String?
    @Published public var successMessage: String?

    private let configStore: ConfigStore
    private let discoveryService: DeviceDiscoveryService

    public init(configStore: ConfigStore, discoveryService: DeviceDiscoveryService) {
        self.configStore = configStore
        self.discoveryService = discoveryService
    }

    // MARK: - Load

    public func loadAll() {
        Task {
            await loadConfig()
            await loadDevices()
            await loadHosts()
        }
    }

    public func loadConfig() async {
        config = await configStore.loadOrDefault(
            AppConfig.self,
            from: "config.json",
            default: AppConfig()
        )
    }

    public func loadDevices() async {
        devices = await discoveryService.discoverDevices()
    }

    public func loadHosts() async {
        hosts = await configStore.loadOrDefault(
            [HostMac].self,
            from: "hosts.json",
            default: []
        )
    }

    // MARK: - Config

    public func saveConfig() {
        Task {
            do {
                try await configStore.save(config, to: "config.json")
                successMessage = "設定を保存しました"
            } catch {
                errorMessage = "設定の保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Devices

    public func refreshDevices() {
        isDiscoveringDevices = true
        Task {
            devices = await discoveryService.discoverDevices()
            isDiscoveringDevices = false
        }
    }

    // MARK: - Hosts

    public func refreshPeers() {
        isDiscoveringPeers = true
        Task {
            peers = await discoveryService.discoverPeers()
            isDiscoveringPeers = false
        }
    }

    public func addHost(label: String, hostName: String) {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLabel.isEmpty else {
            errorMessage = "ラベルを入力してください"
            return
        }

        guard !hosts.contains(where: { $0.label == trimmedLabel }) else {
            errorMessage = "同じ名前のホストが既に登録されています"
            return
        }

        guard hosts.count < 3 else {
            errorMessage = "登録可能な Mac の最大数（3台）に達しました"
            return
        }

        let host = HostMac(label: trimmedLabel, hostName: hostName)
        hosts.append(host)
        saveHosts()
    }

    public func addHostFromPeer(_ peer: PeerInfo) {
        addHost(label: peer.hostName, hostName: peer.hostName)
    }

    public func updateHost(_ host: HostMac) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
            saveHosts()
        }
    }

    public func removeHost(_ host: HostMac) {
        hosts.removeAll { $0.id == host.id }
        saveHosts()
    }

    private func saveHosts() {
        Task {
            do {
                try await configStore.save(hosts, to: "hosts.json")
            } catch {
                errorMessage = "ホスト情報の保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }
}
