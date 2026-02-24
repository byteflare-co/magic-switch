import Foundation
import Network
import Logging

/// 個別ピアとの接続管理
/// NWConnection を使った TCP 通信（TLS 暗号化対応）
/// Blue Switch 互換: テキストベースのコマンド送受信
public actor PeerConnection: PeerCommunicating {
    private let logger = MagicSwitchLogger.network
    private let connection: NWConnection
    private var state: PeerConnectionState = .idle
    private var receiveContinuation: CheckedContinuation<DeviceCommand, Error>?

    /// 受信メッセージのコールバック
    private var receiveHandler: (@Sendable (DeviceCommand) -> Void)?

    /// 受信バッファ（改行区切りテキストの途中受信に対応）
    private var receiveBuffer: String = ""

    /// 既存の NWConnection から初期化（サーバー側で受け入れた接続）
    public init(connection: NWConnection) {
        self.connection = connection
    }

    /// エンドポイントへの新規接続を作成（クライアント側）
    /// Blue Switch 互換: NWProtocolFramer は使わず素の TCP
    public init(
        to endpoint: NWEndpoint,
        useTLS: Bool = false
    ) {
        let parameters: NWParameters
        if useTLS {
            parameters = NWParameters(tls: Self.createTLSOptions())
        } else {
            parameters = NWParameters.tcp
        }

        self.connection = NWConnection(to: endpoint, using: parameters)
    }

    /// 受信メッセージのハンドラを設定
    public func setReceiveHandler(_ handler: @escaping @Sendable (DeviceCommand) -> Void) {
        self.receiveHandler = handler
    }

    /// 接続の開始
    public func start() async throws {
        state = .connecting

        connection.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            Task {
                await self.handleStateChange(newState)
            }
        }

        connection.start(queue: .main)

        // 接続完了を待機
        try await waitForConnection(timeout: .seconds(10))

        // メッセージの受信ループを開始
        startReceiveLoop()
    }

    /// 接続の切断
    public func stop() {
        connection.cancel()
        state = .disconnected
    }

    /// 接続状態の取得
    public func getConnectionState() -> PeerConnectionState {
        state
    }

    /// 接続状態
    public var isConnected: Bool {
        state == .connected
    }

    /// コマンドの送信（Blue Switch 互換テキストプロトコル）
    public func send(_ command: DeviceCommand) async throws {
        guard state == .connected else {
            throw MagicSwitchError.peerUnreachable(hostId: UUID())
        }

        let data = TextMessageProtocol.encode(command)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }

        logger.debug("Sent command: \(command.rawValue)")
    }

    /// メッセージの受信（単一メッセージ）
    public func receive() async throws -> DeviceCommand {
        try await withCheckedThrowingContinuation { continuation in
            self.receiveContinuation = continuation
        }
    }

    /// コマンドを送信し、レスポンスを待機
    public func sendAndWait(
        _ command: DeviceCommand,
        timeout: Duration = .seconds(15)
    ) async throws -> DeviceCommand {
        try await send(command)

        return try await withThrowingTaskGroup(of: DeviceCommand.self) { group in
            group.addTask {
                try await self.receive()
            }

            group.addTask {
                try await Task.sleep(for: timeout)
                throw MagicSwitchError.switchTimeout
            }

            guard let result = try await group.next() else {
                throw MagicSwitchError.switchTimeout
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Private

    private func handleStateChange(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            state = .connected
            logger.info("PeerConnection connected: \(connection.endpoint)")
        case .failed(let error):
            state = .failed(error.localizedDescription)
            logger.error("PeerConnection failed: \(error.localizedDescription)")
        case .cancelled:
            state = .disconnected
        case .preparing, .setup:
            state = .connecting
        case .waiting(let error):
            logger.warning("PeerConnection waiting: \(error.localizedDescription)")
        @unknown default:
            break
        }
    }

    /// 接続完了まで待機
    private func waitForConnection(timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                while await !self.isConnected {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(100))
                    let currentState = await self.getConnectionState()
                    if case .failed = currentState {
                        throw MagicSwitchError.peerUnreachable(hostId: UUID())
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: timeout)
                throw MagicSwitchError.switchTimeout
            }

            try await group.next()
            group.cancelAll()
        }
    }

    /// メッセージ受信ループ（テキストベース）
    private nonisolated func startReceiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            Task {
                await self.handleReceivedData(
                    content: content,
                    error: error,
                    isComplete: isComplete
                )
            }
        }
    }

    private func handleReceivedData(
        content: Data?,
        error: NWError?,
        isComplete: Bool
    ) {
        if let error = error {
            logger.error("Receive error: \(error.localizedDescription)")
            if let continuation = receiveContinuation {
                receiveContinuation = nil
                continuation.resume(throwing: error)
            }
            return
        }

        if let data = content, let text = String(data: data, encoding: .utf8) {
            receiveBuffer += text
            processReceiveBuffer()
        }

        if !isComplete {
            startReceiveLoop()
        }
    }

    /// 受信バッファを処理し、改行区切りでコマンドをパース
    private func processReceiveBuffer() {
        while let newlineIndex = receiveBuffer.firstIndex(of: "\n") {
            let line = String(receiveBuffer[receiveBuffer.startIndex..<newlineIndex])
            receiveBuffer = String(receiveBuffer[receiveBuffer.index(after: newlineIndex)...])

            guard !line.isEmpty else { continue }

            guard let command = DeviceCommand(rawValue: line) else {
                logger.warning("Unknown command received: \(line)")
                continue
            }

            logger.debug("Received command: \(command.rawValue)")

            if let continuation = receiveContinuation {
                receiveContinuation = nil
                continuation.resume(returning: command)
            } else {
                receiveHandler?(command)
            }
        }
    }

    /// TLS オプションの作成
    private static func createTLSOptions() -> NWProtocolTLS.Options {
        let tlsOptions = NWProtocolTLS.Options()

        sec_protocol_options_set_min_tls_protocol_version(
            tlsOptions.securityProtocolOptions,
            .TLSv13
        )

        // TOFU (Trust on First Use) ベースの証明書検証
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, trust, completionHandler in
                let accepted = TrustedPeerStore.shared.verifyPeerCertificate(trust)
                completionHandler(accepted)
            },
            .main
        )

        return tlsOptions
    }
}
