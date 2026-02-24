import Foundation
import Logging

/// アプリケーション全体で使用するロガー
public struct MagicSwitchLogger {
    public static let bluetooth = Logger(label: "com.magicswitch.bluetooth")
    public static let network = Logger(label: "com.magicswitch.network")
    public static let switching = Logger(label: "com.magicswitch.switch")
    public static let ui = Logger(label: "com.magicswitch.ui")
    public static let storage = Logger(label: "com.magicswitch.storage")

    /// ロギングシステムの初期化
    public static func bootstrap(logLevel: LogLevel = .info) {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = logLevel.toSwiftLogLevel()
            return handler
        }
    }
}

extension LogLevel {
    func toSwiftLogLevel() -> Logging.Logger.Level {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warn: return .warning
        case .error: return .error
        }
    }
}
