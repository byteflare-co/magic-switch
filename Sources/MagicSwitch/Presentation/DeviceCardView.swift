import SwiftUI
import MagicSwitchCore

/// ポップオーバー内のデバイスカード
struct DeviceCardView: View {
    let device: MagicDevice

    var body: some View {
        HStack(spacing: 12) {
            // デバイスアイコン
            Image(systemName: device.type == .keyboard ? "keyboard.fill" : "rectangle.on.rectangle.angled")
                .font(.title2)
                .foregroundStyle(device.isConnected ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(.body, weight: .medium))

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

            // バッテリーゲージ
            if let battery = device.batteryLevel {
                BatteryGauge(level: battery)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.background.opacity(0.6))
        )
    }

    private var statusColor: Color {
        switch device.connectionStatus {
        case .connected: return MagicSwitchTheme.online
        case .connecting, .disconnecting: return MagicSwitchTheme.connecting
        case .disconnected: return MagicSwitchTheme.offline
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

/// バッテリーゲージ（プログレスバー版）
struct BatteryGauge: View {
    let level: Int

    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MagicSwitchTheme.batteryColor(for: level))
                        .frame(width: geo.size.width * CGFloat(level) / 100)
                }
            }
            .frame(width: 24, height: 8)

            Text("\(level)%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
