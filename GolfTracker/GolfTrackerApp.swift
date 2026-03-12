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
            // Schema changed — delete the old store and recreate
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            // Also remove journal/wal files
            let dir = url.deletingLastPathComponent()
            let name = url.lastPathComponent
            for suffix in ["-shm", "-wal"] {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(name + suffix))
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { seedDefaultCourseIfNeeded() }
                .task { await CloudKitManager.shared.setup() }
        }
        .modelContainer(sharedModelContainer)
    }

    private func seedDefaultCourseIfNeeded() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Course>()
        let courses = (try? context.fetch(descriptor)) ?? []
        if courses.isEmpty {
            Haymaker.seed(in: context)
        } else if let haymaker = courses.first(where: { $0.name == Haymaker.name }),
                  haymaker.logoData == nil {
            haymaker.logoData = Haymaker.logoData
            try? context.save()
        }
    }
}
