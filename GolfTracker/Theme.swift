import SwiftUI

enum AppTheme {
    // Primary palette — pulled from the app icon
    static let fairwayGreen = Color(red: 0.22, green: 0.44, blue: 0.18)
    static let darkGreen = Color(red: 0.12, green: 0.28, blue: 0.10)
    static let gold = Color(red: 0.76, green: 0.63, blue: 0.30)
    static let goldLight = Color(red: 0.76, green: 0.63, blue: 0.30).opacity(0.12)
    static let warmWhite = Color(red: 0.98, green: 0.97, blue: 0.94)

    // Functional — accent is the gold, used for interactive elements
    static let accent = gold
    static let accentLight = goldLight

    // Score colors — warm palette
    static let eagle = Color(red: 0.16, green: 0.50, blue: 0.72)
    static let birdie = Color(red: 0.22, green: 0.56, blue: 0.24)
    static let par = Color(.label)
    static let bogey = Color(red: 0.80, green: 0.56, blue: 0.18)
    static let double = Color(red: 0.78, green: 0.24, blue: 0.20)

    // Surfaces
    static let cardBackground = Color(.systemBackground)
    static let subtleBackground = Color(.systemGray6)
    static let cornerRadius: CGFloat = 14

    // Header gradient
    static let headerGradient = LinearGradient(
        colors: [darkGreen, fairwayGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func scoreColor(_ toPar: Int) -> Color {
        switch toPar {
        case ...(-2): return eagle
        case -1: return birdie
        case 0: return par
        case 1: return bogey
        default: return double
        }
    }

    // MARK: - Heat Map

    static func heatMapColor(_ avgToPar: Double) -> Color {
        let clamped = min(max(avgToPar, -1.5), 1.5)

        if clamped < -0.5 {
            let t = (clamped + 1.5) / 1.0
            return lerpColor(from: (0.16, 0.50, 0.72), to: (0.22, 0.56, 0.24), t: t)
        } else if clamped < 0.0 {
            let t = (clamped + 0.5) / 0.5
            return lerpColor(from: (0.22, 0.56, 0.24), to: (0.90, 0.92, 0.88), t: t)
        } else if clamped < 0.5 {
            let t = clamped / 0.5
            return lerpColor(from: (0.90, 0.92, 0.88), to: (0.80, 0.56, 0.18), t: t)
        } else {
            let t = (clamped - 0.5) / 1.0
            return lerpColor(from: (0.80, 0.56, 0.18), to: (0.78, 0.24, 0.20), t: t)
        }
    }

    private static func lerpColor(from: (Double, Double, Double), to: (Double, Double, Double), t: Double) -> Color {
        let ct = min(max(t, 0), 1)
        return Color(
            red: from.0 + (to.0 - from.0) * ct,
            green: from.1 + (to.1 - from.1) * ct,
            blue: from.2 + (to.2 - from.2) * ct
        )
    }
}

struct Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
