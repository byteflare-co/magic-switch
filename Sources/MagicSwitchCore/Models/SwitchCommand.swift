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

/// Bluetooth 接続状態（切り替え動作の分岐に使用）
public enum BluetoothConnectionStatus: Sendable {
    case allConnected
    case allDisconnected
    case partial
}
