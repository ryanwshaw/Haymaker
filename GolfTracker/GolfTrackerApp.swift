import SwiftUI
import SwiftData

@main
struct GolfTrackerApp: App {
    @StateObject private var auth = AuthManager.shared
    @State private var showSplash = true

    init() {
        // Match the splash screen background so there's no black flash on launch
        let splashGreen = UIColor(red: 0.20, green: 0.31, blue: 0.24, alpha: 1)
        UIWindow.appearance().backgroundColor = splashGreen
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(GolfTrackerSchemaV2.models)

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: GolfTrackerMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
