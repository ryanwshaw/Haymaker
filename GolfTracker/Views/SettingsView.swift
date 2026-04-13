import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @ObservedObject private var auth = AuthManager.shared
    @State private var showSignOutConfirm = false
    @State private var showNameEditor = false
    @State private var editedName = ""
    // Demo state commented out for App Store release
    // @State private var showDemoConfirm = false
    // @State private var showClearDataConfirm = false
    @AppStorage("caddieEnabled") private var caddieEnabled = true
    @AppStorage("boozingPromptEnabled") private var boozingPromptEnabled = true
    @AppStorage("hasDemoData") private var hasDemoData = false
    @State private var exportURL: URL?
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var backupStatusMessage: String?
    @State private var showBackupAlert = false

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    settingsHeader

                    settingsGroup(title: "ACCOUNT") {
                        accountRow
                    }

                    settingsGroup(title: "GAME") {
                        settingsRow(icon: "medal.fill", iconColor: .orange, title: "My Badges", subtitle: "\(BadgeManager.shared.earnedBadges.count) earned") {
                            BadgeProfileView(
                                playerName: CloudKitManager.shared.displayName,
                                badges: BadgeManager.shared.earnedBadges
                            )
                        }
                        Divider().padding(.leading, 52)
                        settingsRow(icon: "map.fill", iconColor: AppTheme.fairwayGreen, title: "Courses", subtitle: "Manage your courses") {
                            CourseListView()
                        }
                        Divider().padding(.leading, 52)
                        settingsRow(icon: "bag.fill", iconColor: AppTheme.gold, title: "My Bag", subtitle: "Clubs & average yardages") {
                            BagEditorView()
                        }
                    }

                    settingsGroup(title: "ROUND") {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.golf")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.mauve, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Virtual Caddie")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Club recommendations each hole")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $caddieEnabled)
                                .tint(AppTheme.fairwayGreen)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        Divider().padding(.leading, 52)
                        HStack(spacing: 12) {
                            Image(systemName: "wineglass.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.gold, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Booze Tracking Prompt")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Ask before each round")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $boozingPromptEnabled)
                                .tint(AppTheme.fairwayGreen)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }

                    settingsGroup(title: "ABOUT") {
                        aboutRow(label: "Version", value: "1.0")
                        Divider().padding(.leading, 52)
                        aboutRow(label: "Rounds played", value: "\(completedRounds.count)")
                        Divider().padding(.leading, 52)
                        aboutRow(label: "Badges earned", value: "\(BadgeManager.shared.earnedBadges.count)")
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color(.systemGray3), in: RoundedRectangle(cornerRadius: 8))
                                Text("Privacy Policy")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup(title: "DATA & BACKUP") {
                        settingsActionRow(
                            icon: "arrow.up.doc.fill",
                            iconColor: Color(red: 0.2, green: 0.5, blue: 0.85),
                            title: "Export Backup",
                            subtitle: "Save all rounds & courses as a JSON file",
                            isDestructive: false
                        ) {
                            performExport()
                        }
                        Divider().padding(.leading, 52)
                        settingsActionRow(
                            icon: "arrow.down.doc.fill",
                            iconColor: Color(red: 0.2, green: 0.65, blue: 0.45),
                            title: "Restore from Backup",
                            subtitle: "Import a previously exported JSON backup",
                            isDestructive: false
                        ) {
                            showImportPicker = true
                        }
                    }

                    // Demo data section commented out for App Store release
                    // settingsGroup(title: "SHOWCASE") {
                    //     settingsActionRow(icon: "wand.and.stars", ...) { showDemoConfirm = true }
                    //     if hasDemoData { settingsActionRow(icon: "trash", ...) { showClearDataConfirm = true } }
                    // }

                    settingsGroup(title: "") {
                        settingsActionRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            iconColor: AppTheme.double,
                            title: "Sign Out",
                            subtitle: "Sign out of your account",
                            isDestructive: true
                        ) {
                            showSignOutConfirm = true
                        }
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.fairwayGreen)
                }
            }
            // Demo data alerts commented out for App Store release
            // .alert("Load Sample Data?", isPresented: $showDemoConfirm) { ... }
            // .alert("Clear Demo Data?", isPresented: $showClearDataConfirm) { ... }
            .alert("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your data will remain on this device. You can sign back in anytime.")
            }
            .alert("Backup", isPresented: $showBackupAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(backupStatusMessage ?? "")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                performImport(result: result)
            }
        }
    }

    // clearDemoData() commented out for App Store release

    // MARK: - Backup Actions

    private func performExport() {
        Task { @MainActor in
            do {
                let url = try BackupHelper.exportBackup(context: modelContext)
                exportURL = url
                showExportSheet = true
            } catch {
                backupStatusMessage = "Export failed: \(error.localizedDescription)"
                showBackupAlert = true
            }
        }
    }

    private func performImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            let counts = try BackupHelper.importBackup(from: url, context: modelContext)
            let roundLabel = counts.roundsAdded == 1 ? "round" : "rounds"
            let courseLabel = counts.coursesAdded == 1 ? "course" : "courses"
            backupStatusMessage = "Restored \(counts.roundsAdded) \(roundLabel) and \(counts.coursesAdded) \(courseLabel)."
            showBackupAlert = true
        } catch {
            backupStatusMessage = "Restore failed: \(error.localizedDescription)"
            showBackupAlert = true
        }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        VStack(spacing: 6) {
            ZStack {
                Image("HeaderBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.deepGreen.opacity(0.65), AppTheme.darkGreen.opacity(0.35), AppTheme.deepGreen.opacity(0.7)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        VStack(spacing: 4) {
                            Text("HomeCourse Hero")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                            Text("Version 1.0")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.mauve.opacity(0.8))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(AppTheme.fairwayGreen.opacity(0.15), lineWidth: 1)
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
    }

    // MARK: - Reusable Components

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, 4)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }

    private func settingsRow<Destination: View>(icon: String, iconColor: Color, title: String, subtitle: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsActionRow(icon: String, iconColor: Color, title: String, subtitle: String, isDestructive: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(isDestructive ? AppTheme.double : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private var accountRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.fairwayGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(String(auth.displayName.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.fairwayGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    if let email = auth.userEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Apple ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.fairwayGreen)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.leading, 52)

            Button {
                editedName = auth.displayName == "Golfer" ? "" : auth.displayName
                showNameEditor = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.mauve, in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Change Name")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text(auth.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .alert("Change Name", isPresented: $showNameEditor) {
                TextField("Your name", text: $editedName)
                    .textInputAutocapitalization(.words)
                Button("Save") {
                    auth.setCustomName(editedName)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This is the name shown on your profile and badges.")
            }
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color(.systemGray3), in: RoundedRectangle(cornerRadius: 8))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Backup Helper (inlined to avoid Xcode target issues)

private struct BackupRound: Codable {
    var date: Date; var notes: String; var isComplete: Bool
    var teeRaw: String; var isBoozing: Bool; var courseName: String
    var scores: [BackupHoleScore]
}

private struct BackupHoleScore: Codable {
    var holeNumber: Int; var score: Int; var putts: Int
    var holePar: Int; var holeName: String; var holeYardage: Int; var holeMensHdcp: Int
    var teeResultRaw: String; var teeClubRaw: String; var approachDistance: Int
    var approachResultRaw: String; var approachClubRaw: String; var chipClubRaw: String
    var firstPuttDistance: Int; var greensideBunker: Bool; var penalties: Int; var drinksLogged: Int
}

private struct BackupCourse: Codable {
    var name: String; var createdAt: Date; var holes: [BackupCourseHole]
}

private struct BackupCourseHole: Codable {
    var holeNumber: Int; var par: Int; var mensHdcp: Int; var ladiesHdcp: Int
    var name: String; var yardages: [String: Int]
}

private struct BackupPayload: Codable {
    var exportDate: Date; var appVersion: String
    var rounds: [BackupRound]; var courses: [BackupCourse]
}

@MainActor
enum BackupHelper {

    static func exportBackup(context: ModelContext) throws -> URL {
        let rounds = try context.fetch(FetchDescriptor<Round>())
        let courses = try context.fetch(FetchDescriptor<Course>())

        var roundBackups: [BackupRound] = []
        for round in rounds {
            var scoreBackups: [BackupHoleScore] = []
            for hs in round.sortedScores {
                scoreBackups.append(BackupHoleScore(
                    holeNumber: hs.holeNumber, score: hs.score, putts: hs.putts,
                    holePar: hs.holePar, holeName: hs.holeName,
                    holeYardage: hs.holeYardage, holeMensHdcp: hs.holeMensHdcp,
                    teeResultRaw: hs.teeResultRaw, teeClubRaw: hs.teeClubRaw,
                    approachDistance: hs.approachDistance,
                    approachResultRaw: hs.approachResultRaw,
                    approachClubRaw: hs.approachClubRaw,
                    chipClubRaw: hs.chipClubRaw,
                    firstPuttDistance: hs.firstPuttDistance,
                    greensideBunker: hs.greensideBunker,
                    penalties: hs.penalties, drinksLogged: hs.drinksLogged
                ))
            }
            roundBackups.append(BackupRound(
                date: round.date, notes: round.notes, isComplete: round.isComplete,
                teeRaw: round.teeRaw, isBoozing: round.isBoozing,
                courseName: round.courseName, scores: scoreBackups
            ))
        }

        var courseBackups: [BackupCourse] = []
        for course in courses {
            var holeBackups: [BackupCourseHole] = []
            for hole in course.holes {
                holeBackups.append(BackupCourseHole(
                    holeNumber: hole.holeNumber, par: hole.par,
                    mensHdcp: hole.mensHdcp, ladiesHdcp: hole.ladiesHdcp,
                    name: hole.name, yardages: hole.yardages
                ))
            }
            courseBackups.append(BackupCourse(
                name: course.name, createdAt: course.createdAt, holes: holeBackups
            ))
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let backup = BackupPayload(
            exportDate: Date(), appVersion: version,
            rounds: roundBackups, courses: courseBackups
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "HomeCourseHero-backup-\(formatter.string(from: Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tempURL)
        return tempURL
    }

    static func importBackup(from url: URL, context: ModelContext) throws -> (roundsAdded: Int, coursesAdded: Int) {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupPayload.self, from: data)

        let existingCourses = try context.fetch(FetchDescriptor<Course>())
        let existingRounds = try context.fetch(FetchDescriptor<Round>())

        var coursesAdded = 0
        var courseMap: [String: Course] = [:]
        for existing in existingCourses { courseMap[existing.name] = existing }

        for cb in backup.courses where courseMap[cb.name] == nil {
            let course = Course(name: cb.name)
            course.createdAt = cb.createdAt
            for hb in cb.holes {
                let hole = CourseHole(
                    holeNumber: hb.holeNumber, name: hb.name,
                    par: hb.par, mensHdcp: hb.mensHdcp,
                    ladiesHdcp: hb.ladiesHdcp, yardages: hb.yardages
                )
                hole.course = course
                context.insert(hole)
                course.holes.append(hole)
            }
            context.insert(course)
            courseMap[cb.name] = course
            coursesAdded += 1
        }

        let existingDates = Set(existingRounds.map { $0.date })
        var roundsAdded = 0
        for rb in backup.rounds {
            if existingDates.contains(rb.date) { continue }
            let round = Round(
                date: rb.date, notes: rb.notes, isComplete: rb.isComplete,
                tee: rb.teeRaw, isBoozing: rb.isBoozing, course: courseMap[rb.courseName]
            )
            context.insert(round)
            var scores: [HoleScore] = []
            for hsb in rb.scores {
                let hs = HoleScore(
                    holeNumber: hsb.holeNumber, score: hsb.score, putts: hsb.putts,
                    holePar: hsb.holePar, holeName: hsb.holeName,
                    holeYardage: hsb.holeYardage, holeMensHdcp: hsb.holeMensHdcp,
                    teeResultRaw: hsb.teeResultRaw, teeClubRaw: hsb.teeClubRaw,
                    approachDistance: hsb.approachDistance,
                    approachResultRaw: hsb.approachResultRaw,
                    approachClubRaw: hsb.approachClubRaw,
                    chipClubRaw: hsb.chipClubRaw,
                    firstPuttDistance: hsb.firstPuttDistance,
                    greensideBunker: hsb.greensideBunker,
                    penalties: hsb.penalties, drinksLogged: hsb.drinksLogged
                )
                hs.round = round
                context.insert(hs)
                scores.append(hs)
            }
            round.scores = scores
            roundsAdded += 1
        }
        try context.save()
        return (roundsAdded, coursesAdded)
    }
}
