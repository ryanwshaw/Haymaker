import SwiftUI

enum AppTheme {
    // Primary palette — Scheme 3: Sage + Mauve + Gold accent
    static let fairwayGreen = Color(red: 0.314, green: 0.525, blue: 0.376)  // #508660 sage
    static let darkGreen    = Color(red: 0.227, green: 0.420, blue: 0.290)  // #3a6b4a dark sage
    static let deepGreen    = Color(red: 0.10,  green: 0.22,  blue: 0.14)   // #1a3823 for dark surfaces
    static let mauve        = Color(red: 0.784, green: 0.678, blue: 0.733)  // #c8adbb dusty mauve
    static let mauveLight   = Color(red: 0.784, green: 0.678, blue: 0.733).opacity(0.14)
    static let mauveDark    = Color(red: 0.66,  green: 0.53,  blue: 0.62)   // #a8889e deeper mauve
    static let gold         = Color(red: 0.76,  green: 0.63,  blue: 0.30)   // #C2A04D kept as accent
    static let goldLight    = Color(red: 0.76,  green: 0.63,  blue: 0.30).opacity(0.12)
    static let warmWhite    = Color(red: 0.96,  green: 0.95,  blue: 0.93)

    // Functional — mauve is the primary accent; gold used for scores/special highlights
    static let accent      = mauve
    static let accentLight = mauveLight

    // Score colors
    static let eagle  = Color(red: 0.16, green: 0.50, blue: 0.72)
    static let birdie = Color(red: 0.314, green: 0.525, blue: 0.376)  // sage green for birdie
    static let par    = Color(.label)
    static let bogey  = Color(red: 0.80, green: 0.56, blue: 0.18)
    static let double = Color(red: 0.78, green: 0.24, blue: 0.20)

    // Surfaces
    static let cardBackground  = Color(.systemBackground)
    static let subtleBackground = Color(.systemGray6)
    static let cornerRadius: CGFloat = 14

    // Gradients
    static let headerGradient = LinearGradient(
        colors: [darkGreen, fairwayGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let mauveGradient = LinearGradient(
        colors: [mauve, mauveDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let greenGradient = LinearGradient(
        colors: [fairwayGreen, darkGreen],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let deepGreenGradient = LinearGradient(
        colors: [deepGreen, Color(red: 0.14, green: 0.28, blue: 0.18)],
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

// MARK: - Animated Number

struct AnimatedNumber: View, Animatable {
    var value: Double
    var format: String
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(String(format: format, value))
    }
}

// MARK: - Staggered Card Modifier

struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: -geo.size.width * 0.3 + phase * (geo.size.width * 1.6))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
                .mask(content)
            )
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Loading Card

struct SkeletonCard: View {
    var height: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 100, height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 14)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray6))
                .frame(width: 160, height: 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shimmer()
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
