import SwiftUI

/// アプリ全体のテーマ定数
enum MagicSwitchTheme {
    // MARK: - Status Colors

    static let online = Color.green
    static let offline = Color.gray
    static let connecting = Color.orange
    static let error = Color.red
    static let success = Color.green

    // MARK: - Battery Colors

    static func batteryColor(for level: Int) -> Color {
        switch level {
        case ...20: return .red
        case 21...40: return .orange
        default: return .green
        }
    }

    // MARK: - Animations

    static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let easeAnimation = Animation.easeInOut(duration: 0.25)
}
