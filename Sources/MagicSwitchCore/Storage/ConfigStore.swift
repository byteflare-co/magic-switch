import Foundation

/// 設定ストアのプロトコル
public protocol ConfigStoreProtocol: Sendable {
    func load<T: Codable>(_ type: T.Type, from filename: String) async throws -> T
    func save<T: Codable>(_ value: T, to filename: String) async throws
}

/// JSON ベースの設定永続化ストア
public actor ConfigStore: ConfigStoreProtocol {
    private let baseURL: URL

    public init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            self.baseURL = appSupport.appendingPathComponent("MagicSwitch")
        }
    }

    public func load<T: Codable>(_ type: T.Type, from filename: String) async throws -> T {
        let url = baseURL.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    public func save<T: Codable>(_ value: T, to filename: String) async throws {
        try FileManager.default.createDirectory(
            at: baseURL, withIntermediateDirectories: true
        )
        let url = baseURL.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    /// 設定をロードし、存在しない場合はデフォルト値を返す
    public func loadOrDefault<T: Codable & Sendable>(
        _ type: T.Type,
        from filename: String,
        default defaultValue: T
    ) async -> T {
        do {
            return try await load(type, from: filename)
        } catch {
            return defaultValue
        }
    }
}
