import Foundation

/// 接続先 Mac の情報
public struct HostMac: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var label: String
    public let hostName: String
    public var peerHostId: String?
    public var isPaired: Bool
    public var lastSeen: Date?
    public var isOnline: Bool

    public init(
        id: UUID = UUID(),
        label: String,
        hostName: String,
        peerHostId: String? = nil,
        isPaired: Bool = false,
        lastSeen: Date? = nil,
        isOnline: Bool = false
    ) {
        self.id = id
        self.label = label
        self.hostName = hostName
        self.peerHostId = peerHostId
        self.isPaired = isPaired
        self.lastSeen = lastSeen
        self.isOnline = isOnline
    }
}
