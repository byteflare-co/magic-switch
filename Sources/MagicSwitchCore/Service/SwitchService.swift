import Foundation
import Logging

/// リトライポリシー
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let baseDelay: Duration
    public let backoffMultiplier: Double
    public let maxDelay: Duration

    public static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: .seconds(1),
        backoffMultiplier: 2.0,
        maxDelay: .seconds(10)
    )

    public init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .seconds(1),
        backoffMultiplier: Double = 2.0,
        maxDelay: Duration = .seconds(10)
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
    }
}

/// リトライ付き操作実行
public func withRetry<T>(
    policy: RetryPolicy = .default,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    for attempt in 0..<policy.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < policy.maxAttempts - 1 {
                let delaySeconds = policy.baseDelay.seconds * pow(policy.backoffMultiplier, Double(attempt))
                let cappedDelay = min(delaySeconds, policy.maxDelay.seconds)
                try await Task.sleep(for: .milliseconds(Int(cappedDelay * 1000)))
            }
        }
    }
    throw lastError!
}

/// 切り替えオーケストレーションサービス
/// Blue Switch 互換の切り替えロジックを実装:
/// - allConnected: ローカル remove → ポーリング → CONNECT_ALL 送信
/// - allDisconnected: UNREGISTER_ALL 送信 → ローカル pair+connect
/// - partial: 警告通知
public actor SwitchService {
    private let logger = MagicSwitchLogger.switching
    private let bluetooth: BluetoothManager
    private let network: NetworkManager
    private let configStore: ConfigStore
    private let notificationManager: NotificationManager
    private let retryPolicy: RetryPolicy

    /// 切り替え状態
    public enum SwitchState: Sendable {
        case idle
        case switching(progress: SwitchProgress)
        case completed
        case failed(reason: String)
    }

    /// 切り替え進捗
    public struct SwitchProgress: Sendable {
        public let totalDevices: Int
        public var completedDevices: Int
        public var currentPhase: Phase

        public enum Phase: Sendable {
            case releasing
            case acquiring
            case verifying
        }
    }

    /// 状態変更時のコールバック
    public var onStateChanged: (@Sendable (SwitchState) -> Void)?

    private var state: SwitchState = .idle

    /// 相手 Mac からのレスポンス待ち用
    private var pendingResponse: DeviceCommand?

    public init(
        bluetooth: BluetoothManager,
        network: NetworkManager,
        configStore: ConfigStore,
        notificationManager: NotificationManager,
        retryPolicy: RetryPolicy = .default
    ) {
        self.bluetooth = bluetooth
        self.network = network
        self.configStore = configStore
        self.notificationManager = notificationManager
        self.retryPolicy = retryPolicy
    }

    public func currentState() -> SwitchState {
        state
    }

    /// ネットワークコマンドハンドラのセットアップ
    public func setup() async {
        await network.setMessageHandler { [weak self] command, peerId in
            guard let self else { return }
            await self.handleCommand(command, from: peerId)
        }
    }

    /// 一括切り替え（Blue Switch 互換）
    /// 接続状態に応じて動作を分岐する
    public func switchAllDevices(to targetHost: HostMac) async throws {
        guard case .idle = state else {
            throw MagicSwitchError.switchFailed(
                devices: [],
                reason: "別の切り替え処理が実行中です"
            )
        }

        logger.info("Switch initiated -> \(targetHost.label)")

        let devices = await bluetooth.discoverMagicDevices()

        guard !devices.isEmpty else {
            throw MagicSwitchError.switchFailed(
                devices: [],
                reason: "Magic デバイスが見つかりません"
            )
        }

        // 接続状態を判定（Blue Switch 互換の3状態分岐）
        let connectionStatus = await bluetooth.checkConnectionStatus(devices: devices)

        switch connectionStatus {
        case .allConnected:
            // デバイスが全て接続中 → 相手 Mac に送る
            try await handleAllConnected(devices: devices, targetHost: targetHost)

        case .allDisconnected:
            // デバイスが全て切断中 → こちらに引き込む
            try await handleAllDisconnected(devices: devices, targetHost: targetHost)

        case .partial:
            // 一部のみ接続中 → 警告通知
            updateState(.failed(reason: "一部のデバイスのみ接続中です"))
            await notificationManager.notifyPartialConnection()
            updateState(.idle)
            throw MagicSwitchError.partialConnection
        }
    }

    /// デバイスを切り替え先 Mac に切り替え（下位互換メソッド）
    public func switchDevices(
        _ devices: [MagicDevice],
        to targetHost: HostMac
    ) async throws {
        try await switchAllDevices(to: targetHost)
    }

    // MARK: - Blue Switch 互換の切り替えフロー

    /// allConnected: 全デバイス接続中 → 相手 Mac に送る
    /// 1. ローカルで全デバイスを remove
    /// 2. 切断完了をポーリング確認 (最大5回 × 0.5秒)
    /// 3. 相手 Mac に CONNECT_ALL 送信
    private func handleAllConnected(
        devices: [MagicDevice],
        targetHost: HostMac
    ) async throws {
        logger.info("All devices connected - sending to \(targetHost.label)")

        updateState(.switching(progress: SwitchProgress(
            totalDevices: devices.count,
            completedDevices: 0,
            currentPhase: .releasing
        )))

        do {
            // 1. ローカルで全デバイスを remove
            for (index, device) in devices.enumerated() {
                try await withRetry(policy: retryPolicy) {
                    try await self.bluetooth.releaseDevice(device)
                }
                updateState(.switching(progress: SwitchProgress(
                    totalDevices: devices.count,
                    completedDevices: index + 1,
                    currentPhase: .releasing
                )))
                logger.info("Device removed: \(device.name) (\(device.address))")
            }

            // 2. 切断完了をポーリング確認 (最大5回 × 0.5秒)
            let allDisconnected = await bluetooth.pollForDisconnection(devices: devices)
            if !allDisconnected {
                logger.warning("Not all devices disconnected after polling, proceeding anyway")
            }

            // 3. 相手 Mac に CONNECT_ALL 送信
            updateState(.switching(progress: SwitchProgress(
                totalDevices: devices.count,
                completedDevices: devices.count,
                currentPhase: .verifying
            )))

            try await network.sendCommand(.connectAll, to: targetHost.id)
            logger.info("CONNECT_ALL sent to \(targetHost.label)")

            // レスポンスを待機
            let response = try await waitForResponse(timeoutSeconds: 15)
            if response == .operationSuccess {
                updateState(.completed)
                await notificationManager.notifySwitchSuccess(
                    devices: devices,
                    target: targetHost
                )
                logger.info("Switch completed successfully")
            } else {
                throw MagicSwitchError.switchFailed(
                    devices: devices.map(\.address),
                    reason: "相手 Mac での接続に失敗しました"
                )
            }
        } catch {
            let reason = error.localizedDescription
            updateState(.failed(reason: reason))
            logger.error("Switch failed: \(reason)")
            if let switchError = error as? MagicSwitchError {
                await notificationManager.notifySwitchFailure(error: switchError)
            }
            updateState(.idle)
            throw error
        }

        updateState(.idle)
    }

    /// allDisconnected: 全デバイス切断中 → こちらに引き込む
    /// 1. 相手 Mac に UNREGISTER_ALL 送信
    /// 2. ローカルで全デバイスをペアリング+接続
    private func handleAllDisconnected(
        devices: [MagicDevice],
        targetHost: HostMac
    ) async throws {
        logger.info("All devices disconnected - pulling from \(targetHost.label)")

        updateState(.switching(progress: SwitchProgress(
            totalDevices: devices.count,
            completedDevices: 0,
            currentPhase: .acquiring
        )))

        do {
            // 1. 相手 Mac に UNREGISTER_ALL 送信
            try await network.sendCommand(.unregisterAll, to: targetHost.id)
            logger.info("UNREGISTER_ALL sent to \(targetHost.label)")

            // レスポンスを待機
            let response = try await waitForResponse(timeoutSeconds: 15)
            if response != .operationSuccess {
                throw MagicSwitchError.switchFailed(
                    devices: devices.map(\.address),
                    reason: "相手 Mac でのデバイス解除に失敗しました"
                )
            }

            // 2. ローカルで全デバイスをペアリング+接続
            for (index, device) in devices.enumerated() {
                try await withRetry(policy: retryPolicy) {
                    try await self.bluetooth.acquireDevice(device)
                }
                updateState(.switching(progress: SwitchProgress(
                    totalDevices: devices.count,
                    completedDevices: index + 1,
                    currentPhase: .acquiring
                )))
                logger.info("Device acquired: \(device.name) (\(device.address))")
            }

            updateState(.completed)
            await notificationManager.notifySwitchSuccess(
                devices: devices,
                target: targetHost
            )
            logger.info("Switch completed successfully (pull)")
        } catch {
            let reason = error.localizedDescription
            updateState(.failed(reason: reason))
            logger.error("Switch failed: \(reason)")
            if let switchError = error as? MagicSwitchError {
                await notificationManager.notifySwitchFailure(error: switchError)
            }
            updateState(.idle)
            throw error
        }

        updateState(.idle)
    }

    // MARK: - Command Handling

    /// 受信コマンドのハンドリング
    private func handleCommand(_ command: DeviceCommand, from peerId: UUID) async {
        logger.info("Handling command: \(command.rawValue) from \(peerId)")

        switch command {
        case .connectAll:
            await handleConnectAllRequest(from: peerId)

        case .unregisterAll:
            await handleUnregisterAllRequest(from: peerId)

        case .healthCheck:
            try? await network.sendCommand(.operationSuccess, to: peerId)

        case .operationSuccess, .operationFailed:
            pendingResponse = command

        case .notification:
            await notificationManager.notifyRemote(message: "相手 Mac から通知を受信しました")

        case .syncPeripherals, .peripheralData:
            logger.debug("Sync command received (not implemented): \(command.rawValue)")
        }
    }

    /// CONNECT_ALL 受信時: 全デバイスをペアリング+接続
    private func handleConnectAllRequest(from peerId: UUID) async {
        logger.info("Handling CONNECT_ALL request")

        let devices = await loadRegisteredDeviceAddresses()
        var allSuccess = true

        for address in devices {
            do {
                let device = MagicDevice(
                    address: address,
                    name: "Device-\(address)",
                    type: .keyboard
                )
                try await withRetry(policy: retryPolicy) {
                    try await self.bluetooth.acquireDevice(device)
                }
                logger.info("Device acquired via CONNECT_ALL: \(address)")
            } catch {
                logger.error("Failed to acquire device \(address): \(error)")
                allSuccess = false
            }
        }

        let response: DeviceCommand = allSuccess ? .operationSuccess : .operationFailed
        try? await network.sendCommand(response, to: peerId)
        logger.info("CONNECT_ALL response sent: \(response.rawValue)")
    }

    /// UNREGISTER_ALL 受信時: 全デバイスを remove
    private func handleUnregisterAllRequest(from peerId: UUID) async {
        logger.info("Handling UNREGISTER_ALL request")

        let devices = await bluetooth.discoverMagicDevices()
        var allSuccess = true

        for device in devices {
            do {
                try await bluetooth.releaseDevice(device)
                logger.info("Device unregistered via UNREGISTER_ALL: \(device.address)")
            } catch {
                logger.error("Failed to unregister device \(device.address): \(error)")
                allSuccess = false
            }
        }

        let response: DeviceCommand = allSuccess ? .operationSuccess : .operationFailed
        try? await network.sendCommand(response, to: peerId)
        logger.info("UNREGISTER_ALL response sent: \(response.rawValue)")
    }

    // MARK: - Device Persistence

    /// 登録済みデバイスアドレスを保存
    public func saveRegisteredDeviceAddresses(_ addresses: [String]) async {
        try? await configStore.save(addresses, to: "peripherals.json")
    }

    /// 登録済みデバイスアドレスをロード
    private func loadRegisteredDeviceAddresses() async -> [String] {
        await configStore.loadOrDefault(
            [String].self,
            from: "peripherals.json",
            default: []
        )
    }

    // MARK: - Response Waiting

    /// レスポンスの受信を待機（ポーリング + タイムアウト）
    private func waitForResponse(timeoutSeconds: Int) async throws -> DeviceCommand {
        pendingResponse = nil
        let deadline = ContinuousClock.now + .seconds(timeoutSeconds)

        while ContinuousClock.now < deadline {
            if let response = pendingResponse {
                pendingResponse = nil
                return response
            }
            try await Task.sleep(for: .milliseconds(200))
        }

        throw MagicSwitchError.switchTimeout
    }

    // MARK: - Private

    private func updateState(_ newState: SwitchState) {
        state = newState
        onStateChanged?(newState)
    }
}

// MARK: - Duration Extension

extension Duration {
    var seconds: Double {
        let (seconds, attoseconds) = self.components
        return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
    }
}
