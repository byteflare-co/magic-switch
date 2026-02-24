import Foundation
import UserNotifications
import Logging

/// macOS 通知センター連携マネージャ
/// .app バンドル外から実行された場合は通知を無効化し、クラッシュを防ぐ
public actor NotificationManager {
    private let logger = MagicSwitchLogger.ui

    /// UNUserNotificationCenter はバンドルが存在しないと使えないため遅延初期化
    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else {
            return nil
        }
        return UNUserNotificationCenter.current()
    }

    public init() {}

    /// 通知権限のリクエスト
    public func requestAuthorization() async throws -> Bool {
        guard let center else {
            logger.warning("Notification center unavailable (no app bundle)")
            return false
        }
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// 切り替え成功通知
    public func notifySwitchSuccess(
        devices: [MagicDevice],
        target: HostMac
    ) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "切り替え完了"
        let deviceNames = devices.map(\.name).joined(separator: ", ")
        content.body = "\(deviceNames) を \(target.label) に切り替えました"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    /// 切り替え失敗通知
    public func notifySwitchFailure(error: MagicSwitchError) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "切り替え失敗"
        content.body = error.errorDescription ?? "不明なエラーが発生しました"
        content.sound = .default
        content.categoryIdentifier = "SWITCH_FAILURE"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    /// 部分接続警告通知（Blue Switch 互換）
    public func notifyPartialConnection() async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "切り替え不可"
        content.body = "一部のデバイスのみ接続中です。すべてのデバイスの接続状態を揃えてから再試行してください。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    /// リモート通知（相手 Mac から NOTIFICATION コマンド受信時）
    public func notifyRemote(message: String) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Magic Switch"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    /// バッテリー低下通知
    public func notifyLowBattery(device: MagicDevice, level: Int) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "バッテリー残量低下"
        content.body = "\(device.name) のバッテリーが \(level)% です"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "battery-\(device.id.uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
