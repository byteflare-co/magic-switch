import Foundation
import MagicSwitchCore

/// DI コンテナ - サービスの初期化と注入を管理
final class DependencyContainer: @unchecked Sendable {
    // Core
    let configStore: ConfigStore
    let notificationManager: NotificationManager
    let bluetoothManager: BluetoothManager
    let networkManager: NetworkManager

    // Service
    let switchService: SwitchService
    let discoveryService: DeviceDiscoveryService

    init() {
        self.configStore = ConfigStore()
        self.notificationManager = NotificationManager()
        self.bluetoothManager = BluetoothManager()
        self.networkManager = NetworkManager()

        self.switchService = SwitchService(
            bluetooth: bluetoothManager,
            network: networkManager,
            configStore: configStore,
            notificationManager: notificationManager
        )

        self.discoveryService = DeviceDiscoveryService(
            bluetooth: bluetoothManager,
            network: networkManager,
            configStore: configStore
        )
    }

    // MARK: - ViewModel Factory

    @MainActor
    func makeMenuBarViewModel() -> MenuBarViewModel {
        MenuBarViewModel(
            switchService: switchService,
            discoveryService: discoveryService,
            configStore: configStore
        )
    }

    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            configStore: configStore,
            discoveryService: discoveryService
        )
    }

    @MainActor
    func makeSetupWizardViewModel() -> SetupWizardViewModel {
        SetupWizardViewModel(
            discoveryService: discoveryService,
            configStore: configStore
        )
    }
}
