import Testing
@testable import MagicSwitchCore

@Suite("AppConfig Tests")
struct AppConfigTests {
    @Test func testAppConfigDefaultValues() {
        let config = AppConfig()
        #expect(config.launchAtLogin == false)
        #expect(config.showNotifications == true)
        #expect(config.lowBatteryThreshold == 20)
        #expect(config.logLevel == .info)
        #expect(config.switchTimeoutSeconds == 15)
        #expect(config.maxRetryCount == 3)
    }
}

@Suite("MagicDevice Tests")
struct MagicDeviceTests {
    @Test func testMagicDeviceCreation() {
        let device = MagicDevice(
            address: "aa-bb-cc-dd-ee-ff",
            name: "Magic Keyboard",
            type: .keyboard
        )
        #expect(device.address == "aa-bb-cc-dd-ee-ff")
        #expect(device.name == "Magic Keyboard")
        #expect(device.type == .keyboard)
        #expect(device.connectionStatus == .disconnected)
        #expect(device.isConnected == false)
    }
}

@Suite("HostMac Tests")
struct HostMacTests {
    @Test func testHostMacCreation() {
        let host = HostMac(
            label: "仕事用 MacBook Pro",
            hostName: "work-mbp"
        )
        #expect(host.label == "仕事用 MacBook Pro")
        #expect(host.hostName == "work-mbp")
        #expect(host.isPaired == false)
        #expect(host.isOnline == false)
    }
}
