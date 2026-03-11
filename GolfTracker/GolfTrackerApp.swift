import SwiftUI
import SwiftData

@main
struct GolfTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Round.self,
            HoleScore.self,
            Course.self,
            CourseHole.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { seedDefaultCourseIfNeeded() }
        }
        .modelContainer(sharedModelContainer)
    }

    private func seedDefaultCourseIfNeeded() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Course>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            Haymaker.seed(in: context)
        }
    }
}
