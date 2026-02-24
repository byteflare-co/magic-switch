import Foundation

/// Bluetooth デバイス検出プロトコル（テスト用にモック差し替え可能）
public protocol BluetoothDeviceDiscovering: Sendable {
    /// ペアリング済みデバイスの情報を取得
    func pairedDevices() async -> [DiscoveredDevice]

    /// 指定アドレスのデバイスが接続中かどうか
    func isConnected(_ address: String) async -> Bool
}

/// Bluetooth デバイス接続操作プロトコル（Blue Switch 互換 IOBluetooth API）
public protocol BluetoothDeviceConnecting: Sendable {
    /// ペアリング + 接続 (IOBluetoothDevicePair.start() + openConnection)
    func connectPeripheral(address: String) async throws

    /// デバイス情報を OS レベルで削除 (remove セレクター)
    func unregisterFromPC(address: String) async throws

    /// デバイスを切断 (closeConnection)
    func disconnectPeripheral(address: String) async throws
}

/// バッテリー監視プロトコル（テスト用にモック差し替え可能）
public protocol BatteryMonitoring: Sendable {
    /// 指定アドレスのバッテリー残量を取得（0-100, nil = 取得不可）
    func batteryLevel(for address: String) async -> Int?

    /// バッテリー監視を開始
    func startMonitoring(devices: [MagicDevice], interval: Duration) async

    /// バッテリー監視を停止
    func stopMonitoring() async
}

/// IOBluetoothAdapter が返す検出済みデバイス情報
public struct DiscoveredDevice: Sendable {
    public let address: String
    public let name: String
    public let vendorID: UInt16
    public let productID: UInt16
    public let isConnected: Bool

    public init(
        address: String,
        name: String,
        vendorID: UInt16,
        productID: UInt16,
        isConnected: Bool
    ) {
        self.address = address
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
        self.isConnected = isConnected
    }
}
