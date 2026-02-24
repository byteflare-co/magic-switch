import SwiftUI
import MagicSwitchCore

/// ポップオーバー内のホスト切り替えカード
struct HostCardView: View {
    let host: HostMac
    let isCurrent: Bool
    let isSwitching: Bool
    let onSwitch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "desktopcomputer")
                .font(.title3)
                .foregroundStyle(host.isOnline ? .primary : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(host.label)
                        .font(.system(.body, weight: .medium))
                    if isCurrent {
                        Text("(現在)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(host.isOnline ? MagicSwitchTheme.online : MagicSwitchTheme.offline)
                        .frame(width: 6, height: 6)
                    Text(host.isOnline ? "オンライン" : "オフライン")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 切り替えボタン
            if isSwitching {
                ProgressView()
                    .controlSize(.small)
            } else if host.isOnline && !isCurrent {
                Button(action: onSwitch) {
                    Text("切替")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.blue)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}
