import Foundation
import IOBluetooth
import Logging

/// バッテリー残量監視
/// IOBluetooth 経由でバッテリー残量を定期的にポーリングし、低下時に通知する
public actor BatteryMonitor: BatteryMonitoring {
    private let logger = MagicSwitchLogger.bluetooth
    private let adapter: IOBluetoothAdapter
    private let lowBatteryThreshold: Int
    private var monitoringTask: Task<Void, Never>?
    private var lastNotifiedDevices: Set<String> = []

    /// バッテリーレベル変更時のコールバック
    public var onBatteryLevelChanged: (@Sendable (String, Int) -> Void)?

    /// バッテリー低下時のコールバック
    public var onLowBattery: (@Sendable (String, Int) -> Void)?

    public init(
        adapter: IOBluetoothAdapter = IOBluetoothAdapter(),
        lowBatteryThreshold: Int = 20
    ) {
        self.adapter = adapter
        self.lowBatteryThreshold = lowBatteryThreshold
    }

    /// 指定アドレスのバッテリー残量を取得
    public func batteryLevel(for address: String) async -> Int? {
        adapter.batteryLevel(for: address)
    }

    /// バッテリー監視を開始
    /// - Parameters:
    ///   - devices: 監視対象のデバイス一覧
    ///   - interval: ポーリング間隔（デフォルト60秒）
    public func startMonitoring(devices: [MagicDevice], interval: Duration = .seconds(60)) async {
        stopMonitoringInternal()

        logger.info("Starting battery monitoring for \(devices.count) device(s), interval: \(interval)")

        let addresses = devices.map(\.address)

        monitoringTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break
                }
                await self.checkBatteryLevels(addresses: addresses)
            }
        }
    }

    /// バッテリー監視を停止
    public func stopMonitoring() async {
        stopMonitoringInternal()
    }

    // MARK: - Private

    private func stopMonitoringInternal() {
        monitoringTask?.cancel()
        monitoringTask = nil
        lastNotifiedDevices.removeAll()
        logger.info("Battery monitoring stopped")
    }

    /// 各デバイスのバッテリーレベルをチェック
    private func checkBatteryLevels(addresses: [String]) async {
        for address in addresses {
            guard let level = adapter.batteryLevel(for: address) else {
                continue
            }

            logger.debug("Battery level for \(address): \(level)%")

            onBatteryLevelChanged?(address, level)

            // 低バッテリー通知（一度通知したデバイスは充電されるまで再通知しない）
            if level <= lowBatteryThreshold {
                if !lastNotifiedDevices.contains(address) {
                    logger.warning("Low battery for \(address): \(level)%")
                    lastNotifiedDevices.insert(address)
                    onLowBattery?(address, level)
                }
            } else {
                // 閾値を超えたら通知済みフラグをリセット
                lastNotifiedDevices.remove(address)
            }
        }
    }
}
