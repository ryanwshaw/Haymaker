import SwiftUI

struct BadgePopupView: View {
    let badgeType: BadgeType
    let onDismiss: () -> Void

    @State private var phase: AnimationPhase = .hidden
    @State private var textOffset: CGFloat = -20
    @State private var imageScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 0

    private enum AnimationPhase {
        case hidden, entering, visible, exiting
    }

    private var glowColor: Color {
        badgeType.isPositive
            ? Color(red: 1.0, green: 0.85, blue: 0.3)
            : Color(red: 0.9, green: 0.3, blue: 0.3)
    }

    private var titleGradient: LinearGradient {
        if badgeType.isPositive {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.7, blue: 0.2)],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.95, green: 0.35, blue: 0.3), Color(red: 0.75, green: 0.2, blue: 0.2)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(phase == .visible || phase == .entering ? 0.5 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: phase)

            VStack(spacing: 16) {
                Text(badgeType.displayName)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(titleGradient)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    .shadow(color: glowColor.opacity(0.4), radius: 12)
                    .offset(y: textOffset)
                    .opacity(phase == .visible || phase == .entering ? 1 : 0)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [glowColor.opacity(glowOpacity), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)

                    badgeImage
                        .scaleEffect(imageScale)
                }

                Text(badgeType.subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(y: -textOffset * 0.5)
                    .opacity(phase == .visible || phase == .entering ? 1 : 0)
            }
            .opacity(phase == .exiting || phase == .hidden ? 0 : 1)
        }
        .allowsHitTesting(false)
        .onAppear {
            enterAnimation()
        }
    }

    @ViewBuilder
    private var badgeImage: some View {
        if UIImage(named: badgeType.imageName) != nil {
            let img = Image(badgeType.imageName)
                .resizable()
                .scaledToFill()
            if badgeType.isCircularImage {
                img
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.85, green: 0.65, blue: 0.3), Color(red: 0.6, green: 0.4, blue: 0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            } else {
                img
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            }
        } else {
            ZStack {
                Circle()
                    .fill(
                        badgeType.isPositive
                            ? AppTheme.fairwayGreen.opacity(0.25)
                            : AppTheme.bogey.opacity(0.25)
                    )
                    .frame(width: 140, height: 140)
                Image(systemName: badgeType.placeholderSymbol)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
    }

    private func enterAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            phase = .entering
            imageScale = 1.1
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
            textOffset = 0
        }

        withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
            glowOpacity = 0.5
        }

        withAnimation(.spring(response: 0.3).delay(0.5)) {
            imageScale = 1.0
            phase = .visible
        }

        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Haptics.medium()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            exitAnimation()
        }
    }

    private func exitAnimation() {
        withAnimation(.easeIn(duration: 0.4)) {
            phase = .exiting
            imageScale = 0.8
            glowOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onDismiss()
        }
    }
}
