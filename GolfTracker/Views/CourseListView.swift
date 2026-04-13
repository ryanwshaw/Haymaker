import SwiftUI
import SwiftData
import PhotosUI

struct CourseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.createdAt) private var courses: [Course]

    @State private var showScanner = false
    @State private var courseToDelete: Course?
    @State private var showDeleteConfirm = false
    @State private var photoPickerCourse: Course?
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        List {
            Section {
                ForEach(courses) { course in
                    NavigationLink(destination: CourseDetailView(course: course)) {
                        courseRow(course)
                    }
                }
            }

            Section {
                Button {
                    showScanner = true
                } label: {
                    Label("Add Course", systemImage: "plus.circle.fill")
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
        .onChange(of: selectedPhoto) { _, item in
            guard let item, let course = photoPickerCourse else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    if let img = UIImage(data: data),
                       let compressed = img.jpegData(compressionQuality: 0.7) {
                        course.photoData = compressed
                        try? modelContext.save()
                        Haptics.success()
                    }
                }
                selectedPhoto = nil
                photoPickerCourse = nil
            }
        }
    }

    private func courseRow(_ course: Course) -> some View {
        VStack(spacing: 0) {
            if let photo = course.photoImage {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 80)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .simultaneousGesture(TapGesture().onEnded {
                            photoPickerCourse = course
                        })
                    }
            }

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
            .padding(.vertical, 4)
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
        .contextMenu {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Set header photo", systemImage: "photo")
            }
            .simultaneousGesture(TapGesture().onEnded {
                photoPickerCourse = course
            })

            if course.photoData != nil {
                Button(role: .destructive) {
                    course.photoData = nil
                    try? modelContext.save()
                    Haptics.light()
                } label: {
                    Label("Remove header photo", systemImage: "photo.badge.minus")
                }
            }
        }
    }
}
