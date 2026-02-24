import Foundation

/// アプリケーション全体のエラー型
public enum MagicSwitchError: LocalizedError, Sendable {
    // Bluetooth エラー
    case bluetoothDisabled
    case deviceNotFound(address: String)
    case pairFailed(address: String, reason: String)
    case unpairFailed(address: String, reason: String)
    case connectFailed(address: String, reason: String)
    case disconnectFailed(address: String, reason: String)
    case removeFailed(address: String, reason: String)
    case deviceOutOfRange(address: String)

    // ネットワークエラー
    case peerNotFound(hostId: UUID)
    case peerUnreachable(hostId: UUID)
    case connectionTimeout(hostId: UUID, seconds: Int)
    case authenticationFailed(hostId: UUID)

    // 切り替えエラー
    case switchFailed(devices: [String], reason: String)
    case switchPartiallyFailed(succeeded: [String], failed: [String])
    case switchTimeout
    case partialConnection

    // BlueUtil エラー（後方互換用に残す）
    case blueUtilNotFound
    case blueUtilExecutionFailed(code: Int32, message: String)

    // 設定エラー
    case configLoadFailed(String)
    case configSaveFailed(String)
    case maxHostsReached

    public var errorDescription: String? {
        switch self {
        case .bluetoothDisabled:
            return "Bluetooth が無効です"
        case .deviceNotFound(let address):
            return "デバイスが見つかりません: \(address)"
        case .pairFailed(let address, let reason):
            return "ペアリングに失敗しました (\(address)): \(reason)"
        case .unpairFailed(let address, let reason):
            return "ペアリング解除に失敗しました (\(address)): \(reason)"
        case .connectFailed(let address, let reason):
            return "接続に失敗しました (\(address)): \(reason)"
        case .disconnectFailed(let address, let reason):
            return "切断に失敗しました (\(address)): \(reason)"
        case .removeFailed(let address, let reason):
            return "デバイスの登録解除に失敗しました (\(address)): \(reason)"
        case .deviceOutOfRange(let address):
            return "デバイスが Bluetooth の範囲外です: \(address)"
        case .peerNotFound(let hostId):
            return "ピアが見つかりません: \(hostId)"
        case .peerUnreachable(let hostId):
            return "ピアに到達できません: \(hostId)"
        case .connectionTimeout(let hostId, let seconds):
            return "接続がタイムアウトしました (\(hostId)): \(seconds)秒"
        case .authenticationFailed(let hostId):
            return "認証に失敗しました: \(hostId)"
        case .switchFailed(let devices, let reason):
            return "切り替えに失敗しました (\(devices.joined(separator: ", "))): \(reason)"
        case .switchPartiallyFailed(let succeeded, let failed):
            return "一部のデバイスの切り替えに失敗しました。成功: \(succeeded.joined(separator: ", ")), 失敗: \(failed.joined(separator: ", "))"
        case .switchTimeout:
            return "切り替えがタイムアウトしました"
        case .partialConnection:
            return "一部のデバイスのみ接続中です"
        case .blueUtilNotFound:
            return "blueutil が見つかりません"
        case .blueUtilExecutionFailed(let code, let message):
            return "blueutil の実行に失敗しました (コード: \(code)): \(message)"
        case .configLoadFailed(let detail):
            return "設定の読み込みに失敗しました: \(detail)"
        case .configSaveFailed(let detail):
            return "設定の保存に失敗しました: \(detail)"
        case .maxHostsReached:
            return "登録可能な Mac の最大数に達しました"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .bluetoothDisabled:
            return "システム設定から Bluetooth を有効にしてください"
        case .deviceNotFound, .deviceOutOfRange:
            return "デバイスが近くにあり、電源が入っていることを確認してください"
        case .pairFailed, .connectFailed:
            return "デバイスの電源を入れ直し、もう一度お試しください"
        case .peerUnreachable:
            return "切り替え先の Mac が同じネットワークに接続されていることを確認してください"
        case .switchTimeout:
            return "ネットワーク接続を確認し、もう一度お試しください"
        case .partialConnection:
            return "すべてのデバイスの接続状態を揃えてから再試行してください"
        case .blueUtilNotFound:
            return "アプリケーションを再インストールしてください"
        default:
            return nil
        }
    }
}

/// BlueUtil 固有のエラー（後方互換用に残す）
public enum BlueUtilError: Error, Sendable {
    case launchFailed(String)
    case executionFailed(code: Int32, message: String)
}
