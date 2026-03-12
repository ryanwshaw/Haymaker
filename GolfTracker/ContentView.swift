import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedPage = 0
    @State private var showSettings = false
    @Query(sort: \Course.createdAt) private var courses: [Course]

    private var activeCourse: Course? { courses.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.light()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        if let logo = activeCourse?.logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(activeCourse?.name ?? "GolfTracker")
                                .font(.system(size: 17, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                            if let course = activeCourse {
                                Text("\(course.sortedHoles.count) holes · Par \(course.totalPar)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
            }
            .toolbarBackground(AppTheme.darkGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Page Picker

    private var pagePicker: some View {
        HStack(spacing: 0) {
            pageTab("Rounds", index: 0)
            pageTab("Stats", index: 1)
            pageTab("Social", index: 2, badge: CloudKitManager.shared.pendingRequests.count)
        }
        .background(AppTheme.darkGreen)
    }

    private func pageTab(_ title: String, index: Int, badge: Int = 0) -> some View {
        let isActive = selectedPage == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPage = index
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(isActive ? .bold : .medium))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.45))
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppTheme.double, in: Capsule())
                    }
                }
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? AppTheme.gold : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .animation(.spring(response: 0.3), value: selectedPage)
        }
        .buttonStyle(.plain)
    }
}
