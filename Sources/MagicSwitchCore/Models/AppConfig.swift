import Foundation

/// ログレベル
public enum LogLevel: String, Codable, CaseIterable, Sendable {
    case debug
    case info
    case warn
    case error
}

/// キーボードショートカット定義
public struct ShortcutDefinition: Codable, Hashable, Sendable {
    public let key: String
    public let modifiers: [Modifier]

    public enum Modifier: String, Codable, Sendable {
        case control
        case option
        case command
        case shift
    }

    public init(key: String, modifiers: [Modifier]) {
        self.key = key
        self.modifiers = modifiers
    }
}

/// 切り替えプロファイル
public struct SwitchProfile: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var targetHostId: UUID
    public var devices: [UUID]
    public var shortcut: ShortcutDefinition?
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        targetHostId: UUID,
        devices: [UUID] = [],
        shortcut: ShortcutDefinition? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.targetHostId = targetHostId
        self.devices = devices
        self.shortcut = shortcut
        self.sortOrder = sortOrder
    }
}

/// アプリケーション設定
public struct AppConfig: Codable, Equatable, Sendable {
    public var isFirstLaunch: Bool
    public var launchAtLogin: Bool
    public var showNotifications: Bool
    public var lowBatteryThreshold: Int
    public var logLevel: LogLevel
    public var switchTimeoutSeconds: Int
    public var maxRetryCount: Int

    public init(
        isFirstLaunch: Bool = true,
        launchAtLogin: Bool = false,
        showNotifications: Bool = true,
        lowBatteryThreshold: Int = 20,
        logLevel: LogLevel = .info,
        switchTimeoutSeconds: Int = 15,
        maxRetryCount: Int = 3
    ) {
        self.isFirstLaunch = isFirstLaunch
        self.launchAtLogin = launchAtLogin
        self.showNotifications = showNotifications
        self.lowBatteryThreshold = lowBatteryThreshold
        self.logLevel = logLevel
        self.switchTimeoutSeconds = switchTimeoutSeconds
        self.maxRetryCount = maxRetryCount
    }
}
