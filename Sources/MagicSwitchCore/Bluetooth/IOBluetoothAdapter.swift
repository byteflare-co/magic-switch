import Foundation
import IOBluetooth
import Logging

/// Magic デバイスの識別ヘルパー
public enum MagicDeviceIdentifier {
    /// Apple の Bluetooth Vendor ID
    public static let appleVendorID: UInt16 = 0x004C // 76

    /// Magic デバイスの既知の Product ID（世代ごとに異なる）
    public static let knownProductIDs: Set<UInt16> = [
        // Magic Keyboard
        0x0267, // Magic Keyboard (A1644)
        0x029C, // Magic Keyboard with Touch ID (A2449)
        0x029D, // Magic Keyboard with Touch ID and Numeric (A2450)
        0x0314, // Magic Keyboard USB-C (A2980)
        0x0315, // Magic Keyboard with Touch ID USB-C (A2981)
        0x0316, // Magic Keyboard with Touch ID and Numeric USB-C (A2982)
        // Magic Trackpad
        0x0265, // Magic Trackpad 2 (A1535)
        0x0324, // Magic Trackpad USB-C (A2842)
    ]

    /// デバイス名のキーワードでフォールバック判定
    /// macOS ではデバイス名が「ユーザー名のMagic Keyboard」のように
    /// ユーザー名が先頭に付く場合があるため、contains で判定する
    public static let nameKeywords = [
        "Magic Keyboard",
        "Magic Trackpad",
    ]

    /// DiscoveredDevice が Magic デバイスかどうかを判定
    /// vendorID / productID が取得できる場合はそれを優先し、取得できない場合は名前ベースで判定
    public static func isMagicDevice(vendorID: UInt16, productID: UInt16, name: String) -> Bool {
        // 1. Vendor ID が Apple でかつ既知の Product ID にマッチ
        if vendorID == appleVendorID && knownProductIDs.contains(productID) {
            return true
        }

        // 2. デバイス名によるフォールバック（VendorID/ProductID が未取得、または新世代デバイス）
        // 「〇〇のMagic Keyboard」のようにユーザー名が付くケースに対応するため contains で判定
        return nameKeywords.contains(where: { name.contains($0) })
    }

    /// デバイス名から MagicDeviceType を推定
    public static func deviceType(from name: String) -> MagicDeviceType? {
        if name.contains("Keyboard") { return .keyboard }
        if name.contains("Trackpad") { return .trackpad }
        return nil
    }
}

/// IOBluetooth フレームワークのラッパー
/// IOBluetooth はスレッドセーフではないため、BluetoothManager の Actor 内から呼び出すこと
/// Blue Switch 互換: IOBluetooth API を直接使用し、blueutil には依存しない
public final class IOBluetoothAdapter: NSObject, BluetoothDeviceDiscovering, BluetoothDeviceConnecting, @unchecked Sendable {
    private let logger = MagicSwitchLogger.bluetooth

    /// ペアリング完了待ち用
    private var pairingContinuation: CheckedContinuation<Void, Error>?
    private var pairingAddress: String = ""

    public override init() {
        super.init()
    }

    // MARK: - BluetoothDeviceDiscovering

    /// ペアリング済みデバイスの情報を取得
    public func pairedDevices() async -> [DiscoveredDevice] {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            logger.debug("IOBluetoothDevice.pairedDevices() returned nil")
            return []
        }

        return devices.map { device in
            // IORegistry から Vendor ID / Product ID の取得を試みる
            let (vendorID, productID) = queryDeviceIDs(device)

            return DiscoveredDevice(
                address: device.addressString ?? "",
                name: device.name ?? "Unknown",
                vendorID: vendorID,
                productID: productID,
                isConnected: device.isConnected()
            )
        }
    }

    /// 指定アドレスのデバイスが接続中かどうか
    public func isConnected(_ address: String) async -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else {
            return false
        }
        return device.isConnected()
    }

    // MARK: - BluetoothDeviceConnecting (Blue Switch 互換)

    /// ペアリング + 接続 (IOBluetoothDevicePair + openConnection)
    public func connectPeripheral(address: String) async throws {
        guard let device = IOBluetoothDevice(addressString: address) else {
            throw MagicSwitchError.deviceNotFound(address: address)
        }

        // RSSI チェック (127 = 範囲外)
        let rssi = device.rawRSSI()
        if rssi == 127 {
            logger.warning("Device \(address) is out of Bluetooth range (RSSI=127)")
        }

        // IOBluetoothDevicePair でペアリング開始
        guard let pair = IOBluetoothDevicePair(device: device) else {
            throw MagicSwitchError.pairFailed(
                address: address,
                reason: "IOBluetoothDevicePair の作成に失敗しました"
            )
        }
        pair.delegate = self

        logger.info("Starting pairing for device: \(address)")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.pairingContinuation = continuation
            self.pairingAddress = address
            let result = pair.start()
            if result != kIOReturnSuccess {
                self.pairingContinuation = nil
                self.pairingAddress = ""
                continuation.resume(throwing: MagicSwitchError.pairFailed(
                    address: address,
                    reason: "IOBluetoothDevicePair.start() failed: \(result)"
                ))
            }
        }

        // 接続
        logger.info("Opening connection for device: \(address)")
        let connectResult = device.openConnection()
        if connectResult != kIOReturnSuccess {
            throw MagicSwitchError.connectFailed(
                address: address,
                reason: "openConnection failed: \(connectResult)"
            )
        }
        logger.info("Connected peripheral: \(address)")
    }

    /// デバイス情報を OS レベルで削除 (Blue Switch の remove 方式)
    /// private API `remove` セレクターを使用してデバイス情報を削除する
    /// これにより相手 Mac がペアリング+接続可能になる
    public func unregisterFromPC(address: String) async throws {
        guard let device = IOBluetoothDevice(addressString: address) else {
            throw MagicSwitchError.deviceNotFound(address: address)
        }
        logger.info("Unregistering device from PC: \(address)")
        device.perform(Selector(("remove")))
        logger.info("Device unregistered: \(address)")
    }

    /// デバイスを切断 (closeConnection)
    public func disconnectPeripheral(address: String) async throws {
        guard let device = IOBluetoothDevice(addressString: address) else {
            throw MagicSwitchError.deviceNotFound(address: address)
        }
        logger.info("Disconnecting peripheral: \(address)")
        let result = device.closeConnection()
        if result != kIOReturnSuccess {
            throw MagicSwitchError.disconnectFailed(
                address: address,
                reason: "closeConnection failed: \(result)"
            )
        }
        logger.info("Disconnected peripheral: \(address)")
    }

    // MARK: - RSSI

    /// デバイスの RSSI (電波強度) を取得
    /// 127 = 範囲外
    public func rssi(for address: String) -> Int {
        guard let device = IOBluetoothDevice(addressString: address) else {
            return 127
        }
        return Int(device.rawRSSI())
    }

    // MARK: - Battery

    /// IOBluetooth 経由でバッテリー残量を取得
    public func batteryLevel(for address: String) -> Int? {
        guard let device = IOBluetoothDevice(addressString: address),
              device.isConnected() else {
            return nil
        }
        return queryBatteryFromIORegistry(device: device)
    }

    // MARK: - Private

    /// IORegistry からデバイスの Vendor ID / Product ID を取得
    private func queryDeviceIDs(_ device: IOBluetoothDevice) -> (UInt16, UInt16) {
        let address = device.addressString ?? ""
        guard !address.isEmpty else { return (0, 0) }

        let matching = IOServiceMatching("IOBluetoothHIDDriver") as NSMutableDictionary
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != IO_OBJECT_NULL {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }

            let vendorRef = IORegistryEntryCreateCFProperty(entry, "VendorID" as CFString, kCFAllocatorDefault, 0)
            let productRef = IORegistryEntryCreateCFProperty(entry, "ProductID" as CFString, kCFAllocatorDefault, 0)

            if let vendorID = vendorRef?.takeRetainedValue() as? UInt16,
               let productID = productRef?.takeRetainedValue() as? UInt16 {
                let addrRef = IORegistryEntryCreateCFProperty(entry, "DeviceAddress" as CFString, kCFAllocatorDefault, 0)
                if let deviceAddr = addrRef?.takeRetainedValue() as? String,
                   deviceAddr.lowercased() == address.lowercased() {
                    return (vendorID, productID)
                }
            }
        }

        return (0, 0)
    }

    /// IORegistry からバッテリー情報を取得
    private func queryBatteryFromIORegistry(device: IOBluetoothDevice) -> Int? {
        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService") as NSMutableDictionary
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != IO_OBJECT_NULL {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }

            if let batteryRef = IORegistryEntryCreateCFProperty(
                entry,
                "BatteryPercent" as CFString,
                kCFAllocatorDefault,
                0
            ) {
                if let level = batteryRef.takeRetainedValue() as? Int,
                   (0...100).contains(level) {
                    return level
                }
            }
        }

        return nil
    }
}

// MARK: - IOBluetoothDevicePairDelegate

extension IOBluetoothAdapter: IOBluetoothDevicePairDelegate {
    public func devicePairingFinished(_ sender: Any!, error: IOReturn) {
        if error == kIOReturnSuccess {
            logger.info("Pairing finished successfully for: \(pairingAddress)")
            pairingContinuation?.resume()
        } else {
            logger.error("Pairing failed for \(pairingAddress): IOReturn \(error)")
            pairingContinuation?.resume(throwing: MagicSwitchError.pairFailed(
                address: pairingAddress,
                reason: "Pairing finished with error: IOReturn \(error)"
            ))
        }
        pairingContinuation = nil
        pairingAddress = ""
    }
}
