import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @State private var showDeleteConfirm = false
    @State private var isBackfilling = false
    @State private var backfillDone = false

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CourseListView()
                    } label: {
                        Label("Courses", systemImage: "map.fill")
                    }
                }

                Section {
                    NavigationLink {
                        BagEditorView()
                    } label: {
                        Label("My Bag", systemImage: "bag.fill")
                    }
                }

                Section("Data") {
                    if !completedRounds.isEmpty && CloudKitManager.shared.iCloudAvailable {
                        Button {
                            isBackfilling = true
                            Task {
                                await CloudKitManager.shared.backfillRounds(completedRounds)
                                isBackfilling = false
                                backfillDone = true
                                Haptics.success()
                            }
                        } label: {
                            Label(
                                isBackfilling ? "Publishing..." : (backfillDone ? "Rounds published" : "Publish rounds to iCloud"),
                                systemImage: backfillDone ? "checkmark.icloud.fill" : "icloud.and.arrow.up"
                            )
                        }
                        .disabled(isBackfilling || backfillDone)
                    }
                    if completedRounds.isEmpty {
                        Button {
                            MockDataGenerator.generate(in: modelContext)
                            Haptics.success()
                        } label: {
                            Label("Load sample data", systemImage: "wand.and.stars")
                        }
                    }
                    if !allRounds.isEmpty {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete all rounds", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Delete all rounds?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    withAnimation(.spring(response: 0.35)) {
                        for r in allRounds { modelContext.delete(r) }
                        try? modelContext.save()
                    }
                    Haptics.medium()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all rounds and hole data.")
            }
        }
    }
}
