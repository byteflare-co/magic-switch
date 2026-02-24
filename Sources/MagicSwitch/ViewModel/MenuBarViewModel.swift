import Foundation
import MagicSwitchCore

/// 切り替え結果
public enum SwitchResult: Equatable {
    case success(hostLabel: String)
    case failure(message: String)
}

/// メニューバー ViewModel
@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public var connectedDevices: [MagicDevice] = []
    @Published public var hosts: [HostMac] = []
    @Published public var currentHostId: UUID?
    @Published public var isSwitching = false
    @Published public var errorMessage: String?
    @Published public var switchResult: SwitchResult?

    private let switchService: SwitchService
    private let discoveryService: DeviceDiscoveryService
    private let configStore: ConfigStore
    private var refreshTask: Task<Void, Never>?

    public init(
        switchService: SwitchService,
        discoveryService: DeviceDiscoveryService,
        configStore: ConfigStore
    ) {
        self.switchService = switchService
        self.discoveryService = discoveryService
        self.configStore = configStore
    }

    /// デバイスとホスト情報をリフレッシュ
    public func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            let result = await discoveryService.discoverAll()
            self.connectedDevices = result.devices
            self.hosts = result.hosts

            // デバイスアドレスを永続化（CONNECT_ALL 受信時に使用）
            let addresses = result.devices.map(\.address)
            if !addresses.isEmpty {
                await switchService.saveRegisteredDeviceAddresses(addresses)
            }
        }
    }

    /// 指定ホストに切り替え
    public func switchTo(host: HostMac) {
        guard !isSwitching else { return }

        isSwitching = true
        errorMessage = nil
        switchResult = nil

        Task {
            do {
                try await switchService.switchAllDevices(to: host)
                self.currentHostId = host.id
                self.switchResult = .success(hostLabel: host.label)
                self.refresh()
            } catch {
                self.errorMessage = error.localizedDescription
                self.switchResult = .failure(message: error.localizedDescription)
            }
            self.isSwitching = false

            // 3秒後に結果バナーを自動非表示
            try? await Task.sleep(for: .seconds(3))
            self.switchResult = nil
        }
    }

    /// 最初のオンラインホストに切り替え（左クリック用）
    /// Blue Switch 互換: 左クリックで即座に切り替え
    public func switchToFirstOnlineHost() {
        guard !isSwitching else { return }

        // オンラインホストを検索
        guard let targetHost = hosts.first(where: { $0.isOnline }) else {
            errorMessage = "オンラインのホストが見つかりません"
            return
        }

        switchTo(host: targetHost)
    }

    /// デバイスの表示名（バッテリー含む）
    public func displayTitle(for device: MagicDevice) -> String {
        let icon = device.type == .keyboard ? "⌨" : "🔲"
        var title = "\(icon) \(device.name)"
        if let battery = device.batteryLevel {
            title += "  🔋 \(battery)%"
        }
        return title
    }

    /// ホストが現在の接続先かどうか
    public func isCurrentHost(_ host: HostMac) -> Bool {
        host.id == currentHostId
    }
}
