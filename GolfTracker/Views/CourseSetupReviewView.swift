import SwiftUI
import SwiftData
import PhotosUI

struct CourseSetupReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var parsedData: ParsedCourseData
    let scorecardImage: UIImage?
    var onSave: () -> Void

    @State private var logoImage: UIImage?
    @State private var logoPickerItem: PhotosPickerItem?
    @State private var useFromScorecard = false
    @State private var showLogoOptions = false
    @State private var teeColors: [String: String] = [:]

    private let defaultColorOptions: [(String, String)] = [
        ("Black", "1C1C1E"), ("Blue", "007AFF"), ("White", "C7C7CC"),
        ("Gold", "FFD60A"), ("Silver", "8E8E93"), ("Red", "FF3B30"),
        ("Green", "34C759"), ("Orange", "FF9500"),
    ]

    var body: some View {
        NavigationStack {
            List {
                courseNameSection
                logoSection
                teeSection
                holeDataSection
            }
            .navigationTitle("Review Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCourse() }
                        .fontWeight(.bold)
                        .disabled(parsedData.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: logoPickerItem) { _, newItem in
                Task { await loadLogo(from: newItem) }
            }
            .onAppear { initTeeColors() }
        }
    }

    // MARK: - Course Name

    private var courseNameSection: some View {
        Section("Course Name") {
            TextField("Enter course name", text: $parsedData.name)
                .font(.headline)
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        Section("Course Logo") {
            if let logo = logoImage {
                HStack {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logo set")
                            .font(.subheadline.bold())
                        Button("Remove") {
                            logoImage = nil
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                    Spacer()
                }
            }

            if scorecardImage != nil {
                Button {
                    logoImage = scorecardImage
                } label: {
                    Label("Use scorecard as logo", systemImage: "doc.on.clipboard")
                }
            }

            PhotosPicker(selection: $logoPickerItem, matching: .images) {
                Label("Upload separate logo", systemImage: "photo.badge.plus")
            }
        }
    }

    // MARK: - Tees

    private var teeSection: some View {
        Section("Tees") {
            ForEach(Array(parsedData.teeNames.enumerated()), id: \.offset) { i, teeName in
                HStack {
                    TextField("Tee name", text: binding(for: i))
                        .font(.subheadline)

                    Spacer()

                    Menu {
                        ForEach(defaultColorOptions, id: \.0) { name, hex in
                            Button {
                                teeColors[teeName] = hex
                            } label: {
                                Label(name, systemImage: "circle.fill")
                            }
                        }
                    } label: {
                        Circle()
                            .fill(Color(hex: teeColors[teeName] ?? "8E8E93"))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(.quaternary, lineWidth: 1))
                    }

                    Button(role: .destructive) {
                        removeTee(at: i)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                let newName = "Tee \(parsedData.teeNames.count + 1)"
                parsedData.teeNames.append(newName)
                teeColors[newName] = "8E8E93"
            } label: {
                Label("Add tee", systemImage: "plus.circle")
                    .foregroundStyle(AppTheme.fairwayGreen)
            }
        }
    }

    // MARK: - Hole Data

    private var holeDataSection: some View {
        Section("Holes (\(parsedData.holes.count))") {
            ForEach(Array(parsedData.holes.enumerated()), id: \.element.number) { i, hole in
                DisclosureGroup {
                    holeEditor(index: i)
                } label: {
                    HStack {
                        Text("Hole \(hole.number)")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("Par \(hole.par)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !parsedData.teeNames.isEmpty,
                           let firstTee = parsedData.teeNames.first,
                           let yds = hole.yardages[firstTee] {
                            Text("\(yds) yds")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            HStack {
                Button {
                    let n = parsedData.holes.count + 1
                    parsedData.holes.append(.init(number: n, par: 4, hdcp: n, yardages: [:]))
                } label: {
                    Label("Add hole", systemImage: "plus.circle")
                        .foregroundStyle(AppTheme.fairwayGreen)
                }
                Spacer()
                if parsedData.holes.count > 1 {
                    Button(role: .destructive) {
                        parsedData.holes.removeLast()
                    } label: {
                        Label("Remove last", systemImage: "minus.circle")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func holeEditor(index i: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Par")
                    .font(.subheadline)
                Spacer()
                Picker("Par", selection: $parsedData.holes[i].par) {
                    Text("3").tag(3)
                    Text("4").tag(4)
                    Text("5").tag(5)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            HStack {
                Text("Hdcp")
                    .font(.subheadline)
                Spacer()
                TextField("1", value: $parsedData.holes[i].hdcp, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
            ForEach(parsedData.teeNames, id: \.self) { teeName in
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: teeColors[teeName] ?? "8E8E93"))
                            .frame(width: 10, height: 10)
                        Text(teeName)
                            .font(.subheadline)
                    }
                    Spacer()
                    let yardBinding = Binding<Int>(
                        get: { parsedData.holes[i].yardages[teeName] ?? 0 },
                        set: { parsedData.holes[i].yardages[teeName] = $0 }
                    )
                    TextField("0", value: yardBinding, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("yds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline)
    }

    // MARK: - Helpers

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { parsedData.teeNames[index] },
            set: { newValue in
                let oldName = parsedData.teeNames[index]
                if let colorVal = teeColors[oldName] {
                    teeColors[newValue] = colorVal
                    teeColors.removeValue(forKey: oldName)
                }
                for hi in parsedData.holes.indices {
                    if let yds = parsedData.holes[hi].yardages[oldName] {
                        parsedData.holes[hi].yardages.removeValue(forKey: oldName)
                        parsedData.holes[hi].yardages[newValue] = yds
                    }
                }
                parsedData.teeNames[index] = newValue
            }
        )
    }

    private func removeTee(at index: Int) {
        let name = parsedData.teeNames[index]
        teeColors.removeValue(forKey: name)
        for hi in parsedData.holes.indices {
            parsedData.holes[hi].yardages.removeValue(forKey: name)
        }
        parsedData.teeNames.remove(at: index)
    }

    private func initTeeColors() {
        for name in parsedData.teeNames where teeColors[name] == nil {
            let lower = name.lowercased()
            let hex: String
            if lower.contains("black") { hex = "1C1C1E" }
            else if lower.contains("blue") { hex = "007AFF" }
            else if lower.contains("white") { hex = "C7C7CC" }
            else if lower.contains("gold") || lower.contains("yellow") { hex = "FFD60A" }
            else if lower.contains("silver") { hex = "8E8E93" }
            else if lower.contains("red") || lower.contains("ladies") { hex = "FF3B30" }
            else if lower.contains("green") { hex = "34C759" }
            else { hex = "8E8E93" }
            teeColors[name] = hex
        }
    }

    private func loadLogo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run { logoImage = image }
        }
    }

    // MARK: - Save

    private func saveCourse() {
        let tees = parsedData.teeNames.enumerated().map { i, name in
            CourseTeeInfo(
                name: name,
                colorHex: teeColors[name] ?? "8E8E93",
                rating: "—",
                sortOrder: i
            )
        }

        let logoData = logoImage?.jpegData(compressionQuality: 0.8)
        let scorecardData = scorecardImage?.jpegData(compressionQuality: 0.7)

        let course = Course(name: parsedData.name.trimmingCharacters(in: .whitespaces), tees: tees, logoData: logoData)
        course.scorecardImageData = scorecardData
        modelContext.insert(course)

        for hole in parsedData.holes {
            let courseHole = CourseHole(
                holeNumber: hole.number,
                name: "",
                par: hole.par,
                mensHdcp: hole.hdcp,
                ladiesHdcp: 0,
                yardages: hole.yardages
            )
            courseHole.course = course
            modelContext.insert(courseHole)
        }

        try? modelContext.save()
        Haptics.success()
        onSave()
    }
}
