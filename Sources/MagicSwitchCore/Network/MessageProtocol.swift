import Foundation
import Network

/// Blue Switch 互換のテキストベースメッセージプロトコル
/// コマンドは改行区切りのプレーンテキストとして送受信する
/// NWProtocolFramer は使用しない（素の TCP）
public enum TextMessageProtocol {
    /// DeviceCommand をテキストデータにエンコード（改行区切り）
    public static func encode(_ command: DeviceCommand) -> Data {
        Data("\(command.rawValue)\n".utf8)
    }

    /// テキストデータから DeviceCommand をデコード
    /// 改行で区切られた行ごとにパースし、有効なコマンドを返す
    public static func decode(_ data: Data) -> [DeviceCommand] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }
        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { DeviceCommand(rawValue: String($0)) }
    }
}
