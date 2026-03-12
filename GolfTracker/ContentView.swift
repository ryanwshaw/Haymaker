import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedPage = 0
    @State private var showSettings = false
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                appHeader
                pagePicker
                TabView(selection: $selectedPage) {
                    HomeView()
                        .tag(0)
                    StatsView()
                        .tag(1)
                    SocialView()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        ZStack(alignment: .bottom) {
            headerBackground
            VStack(spacing: 0) {
                Spacer().frame(height: topSafeArea)
                headerContent
            }
        }
        .frame(height: topSafeArea + headerContentHeight)
        .clipped()
    }

    private var headerContentHeight: CGFloat {
        completedRounds.isEmpty ? 52 : 86
    }

    private var topSafeArea: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 54
    }

    private var headerBackground: some View {
        Image("HeaderBackground")
            .resizable()
            .scaledToFill()
            .frame(height: topSafeArea + headerContentHeight)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.45), .black.opacity(0.2), .black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }

    private var headerContent: some View {
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

                Text("CourseIQ")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)

                Spacer()

                Color.clear.frame(width: 30, height: 30)
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)

            if !completedRounds.isEmpty {
                heroStatsBar
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Hero Stats

    private var heroStatsBar: some View {
        let full18 = completedRounds.filter(\.hasFull18)
        let avg18: String = full18.isEmpty ? "—" : String(format: "%.0f", Double(full18.map(\.totalScore).reduce(0, +)) / Double(full18.count))
        let best: String = full18.isEmpty ? "—" : "\(full18.map(\.totalScore).min() ?? 0)"
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
        .padding(.vertical, 5)
        .background(.ultraThinMaterial.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 14)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AppTheme.gold)
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

    // MARK: - Page Picker

    private var pagePicker: some View {
        HStack(spacing: 0) {
            pageTab("Rounds", index: 0)
            pageTab("Stats", index: 1)
            pageTab("Social", index: 2, badge: CloudKitManager.shared.pendingRequests.count)
        }
        .padding(.top, 0)
        .padding(.bottom, 2)
        .background(Color.black.opacity(0.75))
    }

    private func pageTab(_ title: String, index: Int, badge: Int = 0) -> some View {
        let isActive = selectedPage == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPage = index
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: isActive ? .bold : .medium))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.45))
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppTheme.double, in: Capsule())
                    }
                }
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? AppTheme.gold : Color.clear)
                    .frame(height: 2.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .animation(.spring(response: 0.3), value: selectedPage)
        }
        .buttonStyle(.plain)
    }
}
