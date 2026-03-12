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

        // Try the default store first
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("Default store failed: \(error)")
        }

        // Nuke everything in Application Support that looks like a SwiftData store
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                for file in contents where file.lastPathComponent.contains("default") ||
                                           file.pathExtension == "store" {
                    try? fm.removeItem(at: file)
                }
            }
        }

        // Retry with an explicit fresh URL
        do {
            let freshURL = URL.applicationSupportDirectory.appending(path: "GolfTracker.store")
            try? FileManager.default.removeItem(at: freshURL)
            let config = ModelConfiguration(url: freshURL)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("Fresh store also failed: \(error)")
        }

        // Last resort: in-memory so the app at least launches
        do {
            let memConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [memConfig])
        } catch {
            fatalError("Could not create any ModelContainer: \(error)")
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
