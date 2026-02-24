import SwiftUI
import MagicSwitchCore

/// デバイス一覧の各行表示
struct DeviceRowView: View {
    let device: MagicDevice

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: deviceIcon)
                .font(.title3)
                .foregroundStyle(device.isConnected ? .primary : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let battery = device.batteryLevel {
                BatteryIndicator(level: battery)
            }
        }
        .padding(.vertical, 4)
    }

    private var deviceIcon: String {
        switch device.type {
        case .keyboard:
            return "keyboard"
        case .trackpad:
            return "rectangle.on.rectangle.angled"
        }
    }

    private var statusColor: Color {
        switch device.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnecting: return .orange
        case .disconnected: return .gray
        }
    }

    private var statusText: String {
        switch device.connectionStatus {
        case .connected: return "接続中"
        case .connecting: return "接続中..."
        case .disconnecting: return "切断中..."
        case .disconnected: return "未接続"
        }
    }
}

/// バッテリーインジケーター
struct BatteryIndicator: View {
    let level: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: batteryIcon)
                .foregroundStyle(batteryColor)
            Text("\(level)%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var batteryIcon: String {
        switch level {
        case 0..<10: return "battery.0percent"
        case 10..<35: return "battery.25percent"
        case 35..<65: return "battery.50percent"
        case 65..<90: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var batteryColor: Color {
        if level <= 20 {
            return .red
        } else if level <= 40 {
            return .orange
        } else {
            return .green
        }
    }
}
