import Foundation

/// Blue Switch 互換のコマンド定義
/// テキストベースの文字列コマンドとして送受信される
public enum DeviceCommand: String, Codable, Sendable {
    case healthCheck = "HEALTH_CHECK"
    case unregisterAll = "UNREGISTER_ALL"
    case connectAll = "CONNECT_ALL"
    case operationSuccess = "OP_SUCCESS"
    case operationFailed = "OP_FAILED"
    case notification = "NOTIFICATION"
    case syncPeripherals = "SYNC_PERIPHERALS"
    case peripheralData = "PERIPHERAL_DATA"
}

/// コマンド + ペイロードを保持するメッセージ構造体
/// `CONNECT_ALL:aa-bb-cc-dd-ee-ff,11-22-33-44-55-66\n` のような拡張フォーマットに対応
public struct DeviceMessage: Sendable {
    public let command: DeviceCommand
    public let payload: String?

    public init(command: DeviceCommand, payload: String? = nil) {
        self.command = command
        self.payload = payload
    }

    /// ペイロードをカンマ区切りのアドレスリストとしてパース
    public var addresses: [String] {
        guard let payload, !payload.isEmpty else { return [] }
        return payload.split(separator: ",").map { String($0) }
    }
}

/// Bluetooth 接続状態（切り替え動作の分岐に使用）
public enum BluetoothConnectionStatus: Sendable {
    case allConnected
    case allDisconnected
    case partial
}
