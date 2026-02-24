import Foundation

/// Magic デバイスの種別
public enum MagicDeviceType: String, Codable, Sendable {
    case keyboard
    case trackpad
}

/// Bluetooth デバイスの接続状態
public enum ConnectionStatus: String, Codable, Sendable {
    case connected
    case disconnected
    case connecting
    case disconnecting
}

/// Magic デバイス
public struct MagicDevice: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let address: String
    public var name: String
    public let type: MagicDeviceType
    public var connectionStatus: ConnectionStatus
    public var batteryLevel: Int?
    public var connectedHostId: UUID?

    public var isConnected: Bool {
        connectionStatus == .connected
    }

    public init(
        id: UUID = UUID(),
        address: String,
        name: String,
        type: MagicDeviceType,
        connectionStatus: ConnectionStatus = .disconnected,
        batteryLevel: Int? = nil,
        connectedHostId: UUID? = nil
    ) {
        self.id = id
        self.address = address
        self.name = name
        self.type = type
        self.connectionStatus = connectionStatus
        self.batteryLevel = batteryLevel
        self.connectedHostId = connectedHostId
    }
}
