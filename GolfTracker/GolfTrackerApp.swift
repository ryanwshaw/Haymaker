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
            let url = config.url
            let dir = url.deletingLastPathComponent()
            let base = url.deletingPathExtension().lastPathComponent

            // Remove every file related to this store
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil) {
                for file in contents where file.lastPathComponent.hasPrefix(base) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            // Fallback: also try the exact URL
            try? FileManager.default.removeItem(at: url)

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
