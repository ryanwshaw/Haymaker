import SwiftUI
import SwiftData

struct CourseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.createdAt) private var courses: [Course]

    @State private var showScanner = false
    @State private var courseToDelete: Course?
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            Section {
                ForEach(courses) { course in
                    courseRow(course)
                }
            }

            Section {
                Button {
                    showScanner = true
                } label: {
                    Label("Add course from scorecard", systemImage: "doc.viewfinder")
                        .foregroundStyle(AppTheme.fairwayGreen)
                }
            }
        }
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            ScorecardScannerView { showScanner = false }
        }
        .alert("Delete course?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let course = courseToDelete {
                    modelContext.delete(course)
                    try? modelContext.save()
                    Haptics.medium()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the course and its hole data. Rounds played at this course will remain but lose their course link.")
        }
    }

    private func courseRow(_ course: Course) -> some View {
        HStack(spacing: 14) {
            if let logo = course.logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.fairwayGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "flag.fill")
                        .foregroundStyle(AppTheme.fairwayGreen)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(course.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(course.holes.count) holes")
                    Text("Par \(course.totalPar)")
                    Text("\(course.teeInfos.count) tees")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if course.name != "Haymaker" {
                Button(role: .destructive) {
                    courseToDelete = course
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
