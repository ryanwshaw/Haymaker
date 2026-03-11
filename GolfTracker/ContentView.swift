import SwiftUI

struct ContentView: View {
    @State private var selectedPage = 0
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pagePicker
                TabView(selection: $selectedPage) {
                    HomeView()
                        .tag(0)
                    StatsView()
                        .tag(1)
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
                    Text("Haymaker")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
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
        }
        .background(AppTheme.darkGreen)
    }

    private func pageTab(_ title: String, index: Int) -> some View {
        let isActive = selectedPage == index
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPage = index
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.45))
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
