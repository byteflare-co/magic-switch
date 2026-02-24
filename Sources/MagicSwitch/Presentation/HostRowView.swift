import SwiftUI
import MagicSwitchCore

/// Mac 一覧の各行表示
struct HostRowView: View {
    let host: HostMac
    let onDelete: (() -> Void)?
    @State private var showDeleteConfirmation = false

    init(host: HostMac, onDelete: (() -> Void)? = nil) {
        self.host = host
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "desktopcomputer")
                .font(.title3)
                .foregroundStyle(host.isOnline ? .primary : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(host.label)
                    .font(.body)
                HStack(spacing: 4) {
                    Circle()
                        .fill(host.isOnline ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(host.isOnline ? "オンライン" : "オフライン")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastSeen = host.lastSeen {
                        Text("(\(lastSeen, style: .relative) 前)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if host.isPaired {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if onDelete != nil {
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .alert("ホストの削除", isPresented: $showDeleteConfirmation) {
            Button("削除", role: .destructive) {
                onDelete?()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(host.label)」を削除しますか？この操作は取り消せません。")
        }
    }
}
