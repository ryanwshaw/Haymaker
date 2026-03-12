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

        // Explicitly disable CloudKit sync — we use CloudKit directly via CloudKitManager,
        // not through SwiftData's automatic sync. Without this, SwiftData sees the iCloud
        // entitlement and tries to connect to a CloudKit container that may not exist yet.
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema changed — nuke the store and retry
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if let contents = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                    for file in contents where file.lastPathComponent.contains("default") ||
                                               file.pathExtension == "store" {
                        try? FileManager.default.removeItem(at: file)
                    }
                }
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
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
