import Foundation
import IOBluetooth
import Logging

/// Bluetooth デバイス管理のプロトコル
public protocol BluetoothManagerProtocol: Sendable {
    func discoverMagicDevices() async -> [MagicDevice]
    func releaseDevice(_ device: MagicDevice) async throws
    func acquireDevice(_ device: MagicDevice) async throws
    func connectDevice(_ device: MagicDevice) async throws
    func disconnectDevice(_ device: MagicDevice) async throws
    func batteryLevel(for device: MagicDevice) async -> Int?
}

/// Bluetooth 統合管理
/// IOBluetoothAdapter を使った高レベル API を提供する
/// Blue Switch 互換: blueutil を使わず IOBluetooth API を直接使用
public actor BluetoothManager: BluetoothManagerProtocol {
    private let logger = MagicSwitchLogger.bluetooth
    private let adapter: IOBluetoothAdapter
    private let batteryMonitor: BatteryMonitoring

    public init(
        adapter: IOBluetoothAdapter? = nil,
        batteryMonitor: BatteryMonitoring? = nil
    ) {
        self.adapter = adapter ?? IOBluetoothAdapter()
        self.batteryMonitor = batteryMonitor ?? BatteryMonitor()
    }

    /// ペアリング済みの Magic デバイスを検出
    public func discoverMagicDevices() async -> [MagicDevice] {
        logger.info("Discovering Magic devices...")

        let allDevices = await adapter.pairedDevices()
        logger.debug("Found \(allDevices.count) paired device(s)")

        let magicDevices = allDevices.compactMap { device -> MagicDevice? in
            guard MagicDeviceIdentifier.isMagicDevice(
                vendorID: device.vendorID,
                productID: device.productID,
                name: device.name
            ) else {
                return nil
            }

            guard let type = MagicDeviceIdentifier.deviceType(from: device.name) else {
                logger.warning("Could not determine device type for: \(device.name)")
                return nil
            }

            let batteryLevel = adapter.batteryLevel(for: device.address)

            return MagicDevice(
                address: device.address,
                name: device.name,
                type: type,
                connectionStatus: device.isConnected ? .connected : .disconnected,
                batteryLevel: batteryLevel
            )
        }

        logger.info("Discovered \(magicDevices.count) Magic device(s)")
        return magicDevices
    }

    /// デバイスを OS レベルで登録解除（切り替え元で実行）
    /// Blue Switch の `unregisterFromPC` に相当
    /// remove 後、デバイスが解放されるのをポーリング確認する
    public func releaseDevice(_ device: MagicDevice) async throws {
        logger.info("Releasing device: \(device.name) (\(device.address))")
        do {
            try await adapter.unregisterFromPC(address: device.address)
            logger.info("Device released: \(device.name)")
        } catch {
            logger.error("Failed to release device \(device.address): \(error)")
            throw MagicSwitchError.unpairFailed(
                address: device.address,
                reason: error.localizedDescription
            )
        }
    }

    /// デバイスのペアリング＋接続（切り替え先で実行）
    /// Blue Switch の `connectPeripheral` に相当
    public func acquireDevice(_ device: MagicDevice) async throws {
        logger.info("Acquiring device: \(device.name) (\(device.address))")
        do {
            try await adapter.connectPeripheral(address: device.address)
            logger.info("Device acquired: \(device.name)")
        } catch {
            logger.error("Failed to acquire device \(device.address): \(error)")
            throw MagicSwitchError.pairFailed(
                address: device.address,
                reason: error.localizedDescription
            )
        }
    }

    /// デバイスに接続
    public func connectDevice(_ device: MagicDevice) async throws {
        logger.info("Connecting device: \(device.name) (\(device.address))")
        do {
            try await adapter.connectPeripheral(address: device.address)
            logger.info("Device connected: \(device.name)")
        } catch {
            logger.error("Failed to connect device \(device.address): \(error)")
            throw MagicSwitchError.connectFailed(
                address: device.address,
                reason: error.localizedDescription
            )
        }
    }

    /// デバイスを切断
    public func disconnectDevice(_ device: MagicDevice) async throws {
        logger.info("Disconnecting device: \(device.name) (\(device.address))")
        do {
            try await adapter.disconnectPeripheral(address: device.address)
            logger.info("Device disconnected: \(device.name)")
        } catch {
            logger.error("Failed to disconnect device \(device.address): \(error)")
            throw MagicSwitchError.disconnectFailed(
                address: device.address,
                reason: error.localizedDescription
            )
        }
    }

    /// デバイスのバッテリー残量を取得
    public func batteryLevel(for device: MagicDevice) async -> Int? {
        await batteryMonitor.batteryLevel(for: device.address)
    }

    /// デバイスの接続状態を確認
    public func isDeviceConnected(_ device: MagicDevice) async -> Bool {
        await adapter.isConnected(device.address)
    }

    /// 接続状態の判定（Blue Switch 互換）
    /// allConnected / allDisconnected / partial の3状態を返す
    public func checkConnectionStatus(devices: [MagicDevice]) async -> BluetoothConnectionStatus {
        guard !devices.isEmpty else { return .allDisconnected }

        var connectedCount = 0
        for device in devices {
            if await adapter.isConnected(device.address) {
                connectedCount += 1
            }
        }

        if connectedCount == devices.count {
            return .allConnected
        } else if connectedCount == 0 {
            return .allDisconnected
        } else {
            return .partial
        }
    }

    /// 切断完了をポーリング確認（Blue Switch 互換）
    /// 最大 maxAttempts 回 × interval 間隔でチェック
    public func pollForDisconnection(
        devices: [MagicDevice],
        maxAttempts: Int = 5,
        interval: Duration = .milliseconds(500)
    ) async -> Bool {
        for attempt in 1...maxAttempts {
            var allDisconnected = true
            for device in devices {
                if await adapter.isConnected(device.address) {
                    allDisconnected = false
                    break
                }
            }
            if allDisconnected {
                logger.info("All devices disconnected after \(attempt) poll(s)")
                return true
            }
            try? await Task.sleep(for: interval)
        }
        logger.warning("Polling for disconnection timed out")
        return false
    }

    /// バッテリー監視を開始
    public func startBatteryMonitoring(
        devices: [MagicDevice],
        interval: Duration = .seconds(60)
    ) async {
        await batteryMonitor.startMonitoring(devices: devices, interval: interval)
    }

    /// バッテリー監視を停止
    public func stopBatteryMonitoring() async {
        await batteryMonitor.stopMonitoring()
    }
}
