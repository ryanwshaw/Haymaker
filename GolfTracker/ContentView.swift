import SwiftUI
import SwiftData

// MARK: - Tab bar extracted to its own view with explicit @Binding
// This gives it a clear identity boundary so SwiftUI can't skip re-renders.

private struct TabPickerBar: View {
    @Binding var selectedPage: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tab("Rounds", icon: "flag.fill",      index: 0)
                tab("Stats",  icon: "chart.bar.fill", index: 1)
                tab("Social", icon: "person.2.fill",  index: 2)
            }
            .padding(.top, 2)

            // Indicator: three equal segments, selected one filled.
            // Uses explicit frame-based layout — no GeometryReader.
            GeometryReader { geo in
                let w = geo.size.width / 3
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.71, green: 0.55, blue: 0.76)) // AppTheme.mauve hardcoded to avoid theme lookup issues
                    .frame(width: w - 32, height: 2.5)
                    .offset(x: CGFloat(selectedPage) * w + 16)
                    .animation(.easeInOut(duration: 0.2), value: selectedPage)
            }
            .frame(height: 2.5)
            .padding(.bottom, 4)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.22, blue: 0.15), Color(red: 0.09, green: 0.18, blue: 0.12)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private func tab(_ title: String, icon: String, index: Int) -> some View {
        Button {
            selectedPage = index
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(selectedPage == index
                        ? Color(red: 0.71, green: 0.55, blue: 0.76)
                        : Color.white.opacity(0.35))
                Text(title)
                    .font(.system(size: 13, weight: selectedPage == index ? .bold : .medium))
                    .foregroundStyle(selectedPage == index ? .white : Color.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selectedPage)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var selectedPage = 0
    @State private var showSettings = false
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }

    var body: some View {
        VStack(spacing: 0) {
            appHeader
                .clipped()

            // Extracted view with @Binding — forces SwiftUI to propagate updates
            TabPickerBar(selectedPage: $selectedPage)

            TabView(selection: $selectedPage) {
                NavigationStack {
                    HomeView().toolbar(.hidden, for: .navigationBar)
                }
                .tag(0)

                NavigationStack {
                    StatsView().toolbar(.hidden, for: .navigationBar)
                }
                .tag(1)

                NavigationStack {
                    SocialView().toolbar(.hidden, for: .navigationBar)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(.container, edges: .top)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - App Header

    private var topSafeArea: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 54
    }

    private var appHeader: some View {
        ZStack(alignment: .bottom) {
            Image("HeaderBackground")
                .resizable()
                .scaledToFill()
                .frame(height: topSafeArea + (completedRounds.isEmpty ? 52 : 86))
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            AppTheme.deepGreen.opacity(0.7),
                            AppTheme.darkGreen.opacity(0.25),
                            AppTheme.deepGreen.opacity(0.85)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            VStack(spacing: 6) {
                HStack(alignment: .center) {
                    Button {
                        Haptics.light()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.15), in: Circle())
                    }

                    Spacer()

                    Text("HomeCourse Hero")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)

                    Spacer()

                    Color.clear.frame(width: 30, height: 30)
                }
                .padding(.horizontal, 18)

                if !completedRounds.isEmpty {
                    heroStatsBar
                }
            }
            .padding(.bottom, 6)
        }
        .frame(height: topSafeArea + (completedRounds.isEmpty ? 52 : 86))
    }

    // MARK: - Hero Stats

    private var heroStatsBar: some View {
        let full18 = completedRounds.filter(\.hasFull18)
        let avg18 = full18.isEmpty ? "—" : String(format: "%.0f", Double(full18.map(\.totalScore).reduce(0, +)) / Double(full18.count))
        let best = full18.isEmpty ? "—" : "\(full18.map(\.totalScore).min() ?? 0)"
        let avgPutts = completedRounds.isEmpty ? 0.0 : Double(completedRounds.map(\.totalPutts).reduce(0, +)) / Double(completedRounds.count)

        return HStack(spacing: 0) {
            heroStat(value: avg18, label: "AVG 18")
            heroDivider
            heroStat(value: best, label: "BEST")
            heroDivider
            heroStat(value: String(format: "%.0f", avgPutts), label: "PUTTS")
            heroDivider
            heroStat(value: "\(completedRounds.count)", label: "ROUNDS")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.deepGreen.opacity(0.5))
        .background(.ultraThinMaterial.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.fairwayGreen.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AppTheme.mauve)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 22)
    }
}
