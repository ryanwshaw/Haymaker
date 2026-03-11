import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Rounds", systemImage: "list.bullet") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            BagEditorView()
                .tabItem { Label("My Bag", systemImage: "bag.fill") }
        }
        .tint(AppTheme.fairwayGreen)
    }
}
