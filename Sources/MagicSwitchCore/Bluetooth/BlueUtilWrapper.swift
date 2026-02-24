import Foundation
import Logging

/// blueutil CLI のラッパー（フォールバック用）
/// メインの切り替えフローでは IOBluetoothAdapter を使用する
/// blueutil が必要な場合のみ使用
public actor BlueUtilWrapper: BluetoothDeviceConnecting {
    private let logger = MagicSwitchLogger.bluetooth
    private let binaryPath: String

    public init(binaryPath: String? = nil) {
        if let path = binaryPath {
            self.binaryPath = path
        } else {
            self.binaryPath = Bundle.main.path(
                forResource: "blueutil",
                ofType: nil
            ) ?? "/opt/homebrew/bin/blueutil"
        }
    }

    /// ペアリング + 接続
    public func connectPeripheral(address: String) async throws {
        logger.info("Pairing device via blueutil: \(address)")
        try await execute(["--pair", address])
        try await execute(["--connect", address])
        logger.info("Connected via blueutil: \(address)")
    }

    /// デバイスの登録解除（unpair）
    public func unregisterFromPC(address: String) async throws {
        logger.info("Unregistering device via blueutil: \(address)")
        try await execute(["--unpair", address])
        logger.info("Unregistered via blueutil: \(address)")
    }

    /// デバイスを切断
    public func disconnectPeripheral(address: String) async throws {
        logger.info("Disconnecting device via blueutil: \(address)")
        try await execute(["--disconnect", address])
        logger.info("Disconnected via blueutil: \(address)")
    }

    // MARK: - Private

    @discardableResult
    private func execute(_ arguments: [String]) async throws -> String {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            logger.error("blueutil not found at: \(binaryPath)")
            throw MagicSwitchError.blueUtilNotFound
        }

        logger.debug("Executing blueutil: \(arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: BlueUtilError.executionFailed(
                        code: proc.terminationStatus,
                        message: errorOutput.isEmpty ? output : errorOutput
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BlueUtilError.launchFailed(
                    error.localizedDescription
                ))
            }
        }
    }
}
