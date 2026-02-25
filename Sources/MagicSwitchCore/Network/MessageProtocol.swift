import Foundation
import Network

/// Blue Switch 互換のテキストベースメッセージプロトコル
/// コマンドは改行区切りのプレーンテキストとして送受信する
/// NWProtocolFramer は使用しない（素の TCP）
///
/// 拡張フォーマット: `COMMAND:payload\n`（ペイロード付き）
/// 既存フォーマット: `COMMAND\n`（後方互換性あり）
public enum TextMessageProtocol {
    /// DeviceCommand をテキストデータにエンコード（改行区切り）
    public static func encode(_ command: DeviceCommand) -> Data {
        Data("\(command.rawValue)\n".utf8)
    }

    /// DeviceCommand + ペイロードをテキストデータにエンコード
    public static func encode(_ command: DeviceCommand, payload: String?) -> Data {
        if let payload, !payload.isEmpty {
            return Data("\(command.rawValue):\(payload)\n".utf8)
        }
        return encode(command)
    }

    /// DeviceCommand + アドレスリストをテキストデータにエンコード
    public static func encode(_ command: DeviceCommand, addresses: [String]) -> Data {
        if addresses.isEmpty {
            return encode(command)
        }
        return encode(command, payload: addresses.joined(separator: ","))
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

    /// 1行のテキストから DeviceMessage をデコード
    /// `COMMAND:payload` または `COMMAND` の両方に対応（後方互換性あり）
    public static func decodeLine(_ line: String) -> DeviceMessage? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let colonIndex = trimmed.firstIndex(of: ":") {
            let commandPart = String(trimmed[trimmed.startIndex..<colonIndex])
            let payloadPart = String(trimmed[trimmed.index(after: colonIndex)...])
            guard let command = DeviceCommand(rawValue: commandPart) else { return nil }
            return DeviceMessage(command: command, payload: payloadPart)
        } else {
            guard let command = DeviceCommand(rawValue: trimmed) else { return nil }
            return DeviceMessage(command: command)
        }
    }
}
