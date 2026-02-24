import Foundation
import AppKit
import CoreBluetooth
import MagicSwitchCore

/// セットアップウィザード ViewModel
@MainActor
public final class SetupWizardViewModel: ObservableObject {
    public enum Step: Int, CaseIterable {
        case permissions = 1
        case deviceSelection = 2
        case hostRegistration = 3
        case completion = 4
    }

    @Published public var currentStep: Step = .permissions
    @Published public var isComplete = false

    // Step 1: Permissions
    @Published public var bluetoothPermissionGranted = false
    @Published public var localNetworkPermissionGranted = false

    // Step 2: Devices
    @Published public var discoveredDevices: [MagicDevice] = []
    @Published public var selectedDeviceIds: Set<UUID> = []
    @Published public var isDiscoveringDevices = false

    // Step 3: Hosts
    @Published public var discoveredPeers: [PeerInfo] = []
    @Published public var registeredHosts: [HostMac] = []
    @Published public var isDiscoveringPeers = false

    private let discoveryService: DeviceDiscoveryService
    private let configStore: ConfigStore

    public init(discoveryService: DeviceDiscoveryService, configStore: ConfigStore) {
        self.discoveryService = discoveryService
        self.configStore = configStore
    }

    // MARK: - Navigation

    public var canProceed: Bool {
        switch currentStep {
        case .permissions:
            return bluetoothPermissionGranted
        case .deviceSelection:
            return !selectedDeviceIds.isEmpty
        case .hostRegistration:
            return !registeredHosts.isEmpty
        case .completion:
            return true
        }
    }

    public var totalSteps: Int { Step.allCases.count }

    public var progress: Double {
        Double(currentStep.rawValue) / Double(totalSteps)
    }

    public func nextStep() {
        guard let nextIndex = Step.allCases.firstIndex(where: { $0.rawValue == currentStep.rawValue + 1 }) else {
            completeSetup()
            return
        }
        currentStep = Step.allCases[nextIndex]
        onStepEntered()
    }

    public func previousStep() {
        guard let prevIndex = Step.allCases.firstIndex(where: { $0.rawValue == currentStep.rawValue - 1 }) else {
            return
        }
        currentStep = Step.allCases[prevIndex]
    }

    // MARK: - Step Actions

    private func onStepEntered() {
        switch currentStep {
        case .permissions:
            checkPermissions()
        case .deviceSelection:
            discoverDevices()
        case .hostRegistration:
            discoverPeers()
        case .completion:
            break
        }
    }

    public func checkPermissions() {
        // Bluetooth 権限: CBManager の authorization ステータスを確認
        let btAuth = CBManager.authorization
        bluetoothPermissionGranted = (btAuth == .allowedAlways)

        // Local Network 権限: macOS では直接チェックする API がないため、
        // Bonjour 使用時にシステムが自動的にプロンプトを表示する
        // Bluetooth が許可されている場合は Network も許可済みと推定
        localNetworkPermissionGranted = bluetoothPermissionGranted
    }

    /// Bluetooth のシステム設定を開く
    public func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }


    public func discoverDevices() {
        isDiscoveringDevices = true
        Task {
            discoveredDevices = await discoveryService.discoverDevices()
            // デフォルトで全デバイスを選択
            selectedDeviceIds = Set(discoveredDevices.map(\.id))
            isDiscoveringDevices = false
        }
    }

    public func toggleDeviceSelection(_ device: MagicDevice) {
        if selectedDeviceIds.contains(device.id) {
            selectedDeviceIds.remove(device.id)
        } else {
            selectedDeviceIds.insert(device.id)
        }
    }

    public func discoverPeers() {
        isDiscoveringPeers = true
        Task {
            let allPeers = await discoveryService.discoverPeers()
            // 既に登録済みのホストを候補から除外
            let registeredNames = Set(registeredHosts.map(\.hostName))
            discoveredPeers = allPeers.filter { !registeredNames.contains($0.hostName) }
            isDiscoveringPeers = false
        }
    }

    public func registerHost(from peer: PeerInfo) {
        guard registeredHosts.count < 3 else { return }
        guard !registeredHosts.contains(where: { $0.hostName == peer.hostName }) else { return }
        let host = HostMac(
            label: peer.hostName,
            hostName: peer.hostName,
            isPaired: true,
            isOnline: true
        )
        registeredHosts.append(host)
    }

    public func removeRegisteredHost(_ host: HostMac) {
        registeredHosts.removeAll { $0.id == host.id }
    }

    // MARK: - Completion

    private func completeSetup() {
        Task {
            // ホスト情報を保存
            try? await configStore.save(registeredHosts, to: "hosts.json")

            // 初回セットアップ完了フラグを保存
            var config = await configStore.loadOrDefault(
                AppConfig.self,
                from: "config.json",
                default: AppConfig()
            )
            config.launchAtLogin = true
            try? await configStore.save(config, to: "config.json")

            isComplete = true
        }
    }
}
