import SwiftUI
import PhotosUI
import Vision
import UIKit

struct ScorecardScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var scorecardImage: UIImage?
    @State private var isProcessing = false
    @State private var parsedCourse: ParsedCourseData?
    @State private var showReview = false
    @State private var showCamera = false
    @State private var showClipboardAlert = false
    @State private var clipboardAlertMessage = ""
    @State private var showURLInput = false
    @State private var courseURL = ""
    @State private var urlError = ""
    @State private var blueGolfSearch = ""
    @State private var showCourseSearch = false
    @State private var courseSearchQuery = ""
    @State private var searchResults: [GCSearchResult] = []
    @State private var searchError = ""
    @State private var isSearching = false
    @State private var isFetchingCourse = false

    var onCourseCreated: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = scorecardImage {
                    scorecardPreview(image)
                } else {
                    uploadPrompt
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showReview) {
                if let parsed = parsedCourse {
                    CourseSetupReviewView(
                        parsedData: parsed,
                        scorecardImage: scorecardImage,
                        onSave: {
                            onCourseCreated()
                            dismiss()
                        }
                    )
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    scorecardImage = image
                    showCamera = false
                }
            }
            .sheet(isPresented: $showURLInput) {
                urlInputSheet
            }
            .sheet(isPresented: $showCourseSearch) {
                courseSearchSheet
            }
            .alert("Clipboard", isPresented: $showClipboardAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(clipboardAlertMessage)
            }
        }
    }

    // MARK: - Upload Prompt

    private var uploadPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "flag.and.flag.filled.crossed")
                .font(.system(size: 50))
                .foregroundStyle(AppTheme.fairwayGreen)

            VStack(spacing: 6) {
                Text("Add a Course")
                    .font(.title2.bold())
                Text("Search from 30,000+ courses, or import from a course website.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                // Search by name (primary)
                Button {
                    courseSearchQuery = ""
                    searchResults = []
                    searchError = ""
                    showCourseSearch = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                        Text("Search by Name")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        LinearGradient(colors: [AppTheme.fairwayGreen, AppTheme.darkGreen],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    )
                    .shadow(color: AppTheme.fairwayGreen.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)

                // Website import (fallback)
                Button {
                    courseURL = ""
                    urlError = ""
                    showURLInput = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.headline)
                        Text("Import from Website")
                            .font(.headline)
                    }
                    .foregroundStyle(AppTheme.fairwayGreen)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.fairwayGreen.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(AppTheme.fairwayGreen.opacity(0.4), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            Spacer()
        }
    }

    // MARK: - URL Input Sheet

    private var urlInputSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // BlueGolf search (recommended)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.gold)
                            Text("Recommended: Search BlueGolf")
                                .font(.subheadline.bold())
                        }

                        Text("BlueGolf has detailed scorecards for thousands of courses. Search for yours, then tap \"Import\" to pull in all the data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            TextField("Course name (e.g. Haymaker)", text: $blueGolfSearch)
                                .textInputAutocapitalization(.words)
                                .padding(10)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))

                            Button {
                                openBlueGolfSearch()
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(AppTheme.fairwayGreen, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(blueGolfSearch.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        Text("Search on BlueGolf, find your course, go to Tees > \"Show All\", then copy the page URL and paste it below.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(AppTheme.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                    )

                    // Divider
                    HStack {
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                        Text("Paste URL")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Rectangle().fill(Color(.systemGray4)).frame(height: 1)
                    }

                    TextField("https://course.bluegolf.com/...", text: $courseURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                    if !urlError.isEmpty {
                        Text(urlError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if isProcessing {
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(AppTheme.fairwayGreen)
                            Text("Fetching scorecard data...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await fetchFromURL() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.doc")
                                Text("Import Scorecard")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(AppTheme.fairwayGreen, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(courseURL.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(courseURL.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Import from Website")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showURLInput = false
                    }
                }
            }
        }
    }

    private func openBlueGolfSearch() {
        let query = blueGolfSearch.trimmingCharacters(in: .whitespaces)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://course.bluegolf.com/bluegolf/course/search.htm?q=\(query)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Course Search Sheet

    private var courseSearchSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search course name...", text: $courseSearchQuery)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onSubmit { performSearch() }
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    } else if !courseSearchQuery.isEmpty {
                        Button {
                            courseSearchQuery = ""
                            searchResults = []
                            searchError = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)

                if !searchError.isEmpty {
                    Text(searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                if isFetchingCourse {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppTheme.fairwayGreen)
                        Text("Loading course data...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if searchResults.isEmpty && !courseSearchQuery.isEmpty && !isSearching {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "flag.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("No courses found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Try a different name or use Import from Website instead.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "flag.and.flag.filled.crossed")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text("Search 30,000+ courses")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Type a course or club name and hit search.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(searchResults) { result in
                        Button {
                            Task { await selectCourse(result) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.fairwayGreen)
                                    .frame(width: 32, height: 32)
                                    .background(AppTheme.fairwayGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.displayName)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    if !result.locationString.isEmpty {
                                        Text(result.locationString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Find Your Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCourseSearch = false }
                }
            }
            .onChange(of: courseSearchQuery) { _, newValue in
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    searchResults = []
                    return
                }
                debounceSearch()
            }
        }
    }

    @State private var searchTask: Task<Void, Never>?

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { performSearch() }
        }
    }

    private func performSearch() {
        let query = courseSearchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        isSearching = true
        searchError = ""

        Task {
            do {
                let results = try await GolfCourseAPIService.shared.searchCourses(query: query)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchError = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }

    private func selectCourse(_ result: GCSearchResult) async {
        if result.hasTeeData {
            // Search result already contains full tee/hole data — use it directly
            let parsed = result.toParsedCourseData()
            await MainActor.run {
                parsedCourse = parsed
                showCourseSearch = false
                showReview = true
            }
            return
        }

        // Fallback: fetch full details if search result had no tee data
        await MainActor.run {
            isFetchingCourse = true
            searchError = ""
        }

        do {
            let detail = try await GolfCourseAPIService.shared.fetchCourseDetails(id: result.id)
            let parsed = detail.toParsedCourseData()

            await MainActor.run {
                isFetchingCourse = false
                parsedCourse = parsed
                showCourseSearch = false
                showReview = true
            }
        } catch {
            await MainActor.run {
                isFetchingCourse = false
                searchError = "Couldn't load course: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - URL Fetch

    private func fetchFromURL() async {
        let trimmed = courseURL.trimmingCharacters(in: .whitespaces)
        var urlString = trimmed
        if !urlString.lowercased().hasPrefix("http") {
            urlString = "https://\(urlString)"
        }

        guard let url = URL(string: urlString) else {
            urlError = "That doesn't look like a valid URL."
            return
        }

        await MainActor.run {
            isProcessing = true
            urlError = ""
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                await MainActor.run {
                    urlError = "Couldn't load that page. Check the URL and try again."
                    isProcessing = false
                }
                return
            }

            guard let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .ascii) else {
                await MainActor.run {
                    urlError = "Couldn't read the page content."
                    isProcessing = false
                }
                return
            }

            let parsed = WebScorecardParser.parse(html: html, sourceURL: urlString)

            await MainActor.run {
                isProcessing = false
                if parsed.holes.allSatisfy({ $0.par == 4 && $0.yardages.isEmpty }) {
                    urlError = "Couldn't find scorecard data on that page. Try a page with a scorecard table showing par, yardages, and handicaps."
                } else {
                    parsedCourse = parsed
                    showURLInput = false
                    showReview = true
                }
            }
        } catch {
            await MainActor.run {
                urlError = "Network error: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }

    private func pasteFromClipboard() {
        if let image = UIPasteboard.general.image {
            scorecardImage = image
        } else {
            clipboardAlertMessage = "No image found on the clipboard. Copy a scorecard screenshot first, then tap Paste."
            showClipboardAlert = true
        }
    }

    // MARK: - Preview

    private func scorecardPreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(AppTheme.fairwayGreen)
                    Text("Reading scorecard...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } else {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text("Choose different")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.fairwayGreen)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(AppTheme.fairwayGreen.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task { await loadImage(from: newItem) }
                    }

                    Button {
                        Task { await processImage(image) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "text.viewfinder")
                            Text("Extract Data")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.fairwayGreen,
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Image Loading

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run {
                scorecardImage = image
            }
        }
    }

    // MARK: - OCR Processing

    private func processImage(_ image: UIImage) async {
        await MainActor.run { isProcessing = true }

        guard let cgImage = image.cgImage else {
            await MainActor.run { isProcessing = false }
            return
        }

        let recognizedTexts = await performOCR(on: cgImage)
        let parsed = ScorecardParser.parse(texts: recognizedTexts)

        await MainActor.run {
            parsedCourse = parsed
            isProcessing = false
            showReview = true
        }
    }

    private func performOCR(on cgImage: CGImage) async -> [(String, CGRect)] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let results = observations.compactMap { obs -> (String, CGRect)? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return (candidate.string, obs.boundingBox)
                }
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

// MARK: - Parsed Data Model

struct ParsedCourseData {
    var name: String
    var holes: [ParsedHole]
    var teeNames: [String]

    struct ParsedHole {
        var number: Int
        var par: Int
        var hdcp: Int
        var yardages: [String: Int]
    }
}

// MARK: - Scorecard Parser

struct ScorecardParser {

    private static let teeColorKeywords: Set<String> = [
        "black", "blue", "white", "gold", "silver", "red",
        "green", "orange", "champion", "tips", "yellow",
        "copper", "maroon", "combo"
    ]

    private static let hdcpLabels: Set<String> = [
        "hdcp", "hcp", "handicap"
    ]

    private static let ladiesLabels: Set<String> = [
        "l", "ladies", "ladies'", "women", "women's", "womens"
    ]

    static func parse(texts: [(String, CGRect)]) -> ParsedCourseData {
        let rows = groupIntoRows(texts)

        var courseName = ""
        var parNumbers: [Int] = []
        var mensHdcpNumbers: [Int] = []
        var teeYardageRows: [(name: String, yardages: [Int])] = []
        var foundFirstHdcp = false

        for row in rows {
            let rawStrings = row.map { $0.0 }
            let allTokens = tokenize(rawStrings)
            let labels = allTokens.filter { Int($0) == nil }.map { $0.lowercased() }
            let allNumbers = allTokens.compactMap { Int($0) }

            let hasParLabel = labels.contains("par")
            let hasHdcpLabel = labels.contains(where: { hdcpLabels.contains($0) })
            let hasLadiesLabel = labels.contains(where: { ladiesLabels.contains($0) })
            let isHoleRow = labels.contains("hole") || labels.contains("holes")

            if isHoleRow { continue }

            // Par row: labeled or all values 3-5
            if hasParLabel {
                let pars = allNumbers.filter { (3...5).contains($0) }
                if pars.count >= 9 {
                    if parNumbers.isEmpty {
                        parNumbers = pars
                    } else if parNumbers.count < 18 && pars.count <= 9 {
                        parNumbers.append(contentsOf: pars)
                    }
                }
                continue
            }

            // Handicap row: labeled or all values 1-18 in non-sequential order
            if hasHdcpLabel {
                let hdcps = allNumbers.filter { (1...18).contains($0) }
                if hdcps.count >= 9 {
                    if hasLadiesLabel { continue }
                    if !foundFirstHdcp {
                        mensHdcpNumbers = hdcps.count <= 18 ? hdcps : Array(hdcps.prefix(18))
                        foundFirstHdcp = true
                    } else if mensHdcpNumbers.count < 18 && hdcps.count <= 9 {
                        mensHdcpNumbers.append(contentsOf: hdcps)
                    }
                }
                continue
            }

            // Yardage row: has a tee color keyword and numbers in 50-700
            let teeLabel = labels.first(where: { teeColorKeywords.contains($0) })
            let yardages = allNumbers.filter { (50...700).contains($0) }
            if yardages.count >= 9 {
                let name = teeLabel?.capitalized ?? "Tee \(teeYardageRows.count + 1)"
                if let existing = teeYardageRows.firstIndex(where: { $0.name == name }),
                   teeYardageRows[existing].yardages.count < 18 && yardages.count <= 9 {
                    teeYardageRows[existing].yardages.append(contentsOf: yardages)
                } else {
                    teeYardageRows.append((name: name, yardages: yardages))
                }
                continue
            }

            // Unlabeled rows — infer type from value ranges
            if allNumbers.count >= 9 {
                let inParRange = allNumbers.filter { (3...5).contains($0) }
                let inHdcpRange = allNumbers.filter { (1...18).contains($0) }
                let inYardRange = allNumbers.filter { (50...700).contains($0) }

                if inParRange.count >= 9 && parNumbers.isEmpty {
                    parNumbers = inParRange
                } else if inYardRange.count >= 9 {
                    let name = "Tee \(teeYardageRows.count + 1)"
                    teeYardageRows.append((name: name, yardages: inYardRange))
                } else if inHdcpRange.count >= 9 {
                    let isSequential = inHdcpRange == Array(1...inHdcpRange.count)
                        || inHdcpRange == Array(1...9)
                        || inHdcpRange == Array(10...18)
                    if isSequential { continue }

                    if !foundFirstHdcp {
                        mensHdcpNumbers = inHdcpRange.count <= 18 ? inHdcpRange : Array(inHdcpRange.prefix(18))
                        foundFirstHdcp = true
                    }
                }
            }

            // Course name: short non-numeric text near the top
            if courseName.isEmpty && allNumbers.count < 3 {
                let text = rawStrings.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 2 && !text.allSatisfy(\.isNumber) {
                    courseName = text
                }
            }
        }

        let teeNames = teeYardageRows.map { $0.name }

        let holeCount = max(parNumbers.count, mensHdcpNumbers.count, 18)
        var holes: [ParsedCourseData.ParsedHole] = []

        for i in 0..<holeCount {
            var yardages: [String: Int] = [:]
            for teeRow in teeYardageRows {
                if i < teeRow.yardages.count {
                    yardages[teeRow.name] = teeRow.yardages[i]
                }
            }
            holes.append(ParsedCourseData.ParsedHole(
                number: i + 1,
                par: i < parNumbers.count ? parNumbers[i] : 4,
                hdcp: i < mensHdcpNumbers.count ? mensHdcpNumbers[i] : i + 1,
                yardages: yardages
            ))
        }

        return ParsedCourseData(name: courseName, holes: holes, teeNames: teeNames)
    }

    /// Split OCR text observations into individual tokens.
    /// Vision often returns "4 3 5 4 4 3 4 5 4 36" as a single string.
    private static func tokenize(_ strings: [String]) -> [String] {
        strings
            .flatMap { $0.components(separatedBy: .whitespaces) }
            .map { $0.trimmingCharacters(in: CharacterSet.letters.inverted.subtracting(.decimalDigits)) }
            .map { cleanOCRArtifacts($0) }
            .filter { !$0.isEmpty }
    }

    /// Fix common OCR misreads (O→0, l→1, etc.)
    private static func cleanOCRArtifacts(_ token: String) -> String {
        guard Int(token) == nil else { return token }
        var cleaned = token
        cleaned = cleaned.replacingOccurrences(of: "O", with: "0")
        cleaned = cleaned.replacingOccurrences(of: "o", with: "0")
        cleaned = cleaned.replacingOccurrences(of: "l", with: "1")
        cleaned = cleaned.replacingOccurrences(of: "I", with: "1")
        if Int(cleaned) != nil { return cleaned }
        return token
    }

    private static func groupIntoRows(_ texts: [(String, CGRect)]) -> [[(String, CGRect)]] {
        let sorted = texts.sorted { $0.1.midY > $1.1.midY }
        var rows: [[(String, CGRect)]] = []
        var currentRow: [(String, CGRect)] = []
        var currentY: CGFloat = -1

        let threshold: CGFloat = 0.015

        for item in sorted {
            let midY = item.1.midY
            if currentY < 0 {
                currentY = midY
                currentRow = [item]
            } else if abs(midY - currentY) < threshold {
                currentRow.append(item)
            } else {
                if !currentRow.isEmpty {
                    rows.append(currentRow.sorted { $0.1.midX < $1.1.midX })
                }
                currentRow = [item]
                currentY = midY
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow.sorted { $0.1.midX < $1.1.midX })
        }

        return rows
    }
}

// MARK: - Web Scorecard Parser

struct WebScorecardParser {

    static func parse(html: String, sourceURL: String = "") -> ParsedCourseData {
        let tables = extractTables(from: html)
        var courseName = extractTitle(from: html)
        var bestResult: ParsedCourseData?

        for table in tables {
            if let parsed = parseTable(table), hasMeaningfulData(parsed) {
                if bestResult == nil || scoreQuality(parsed) > scoreQuality(bestResult!) {
                    bestResult = parsed
                }
            }
        }

        if let result = bestResult {
            if courseName.isEmpty { courseName = result.name }
            return ParsedCourseData(
                name: courseName.isEmpty ? "New Course" : courseName,
                holes: result.holes,
                teeNames: result.teeNames
            )
        }

        return ParsedCourseData(
            name: courseName.isEmpty ? "New Course" : courseName,
            holes: (1...18).map { .init(number: $0, par: 4, hdcp: $0, yardages: [:]) },
            teeNames: []
        )
    }

    private static func hasMeaningfulData(_ data: ParsedCourseData) -> Bool {
        let hasPar = data.holes.contains(where: { $0.par != 4 })
        let hasYardage = data.holes.contains(where: { !$0.yardages.isEmpty })
        return hasPar || hasYardage
    }

    private static func scoreQuality(_ data: ParsedCourseData) -> Int {
        var score = 0
        if data.holes.contains(where: { $0.par != 4 }) { score += 10 }
        if data.holes.contains(where: { !$0.yardages.isEmpty }) { score += 10 }
        if data.holes.contains(where: { $0.hdcp != $0.number }) { score += 5 }
        score += data.teeNames.count
        score += data.holes.count
        return score
    }

    // MARK: - HTML Table Extraction

    private static func extractTables(from html: String) -> [[[String]]] {
        var tables: [[[String]]] = []
        let tablePattern = try! NSRegularExpression(
            pattern: "<table[^>]*>(.*?)</table>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        let range = NSRange(html.startIndex..., in: html)

        for match in tablePattern.matches(in: html, range: range) {
            if let tableRange = Range(match.range(at: 1), in: html) {
                let tableHTML = String(html[tableRange])
                tables.append(extractRows(from: tableHTML))
            }
        }

        return tables
    }

    private static func extractRows(from tableHTML: String) -> [[String]] {
        var rows: [[String]] = []
        let rowPattern = try! NSRegularExpression(
            pattern: "<tr[^>]*>(.*?)</tr>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        let range = NSRange(tableHTML.startIndex..., in: tableHTML)

        for match in rowPattern.matches(in: tableHTML, range: range) {
            if let rowRange = Range(match.range(at: 1), in: tableHTML) {
                let rowHTML = String(tableHTML[rowRange])
                rows.append(extractCells(from: rowHTML))
            }
        }

        return rows
    }

    private static func extractCells(from rowHTML: String) -> [String] {
        let cellPattern = try! NSRegularExpression(
            pattern: "<t[dh][^>]*>(.*?)</t[dh]>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        )
        let range = NSRange(rowHTML.startIndex..., in: rowHTML)

        return cellPattern.matches(in: rowHTML, range: range).compactMap { match in
            if let cellRange = Range(match.range(at: 1), in: rowHTML) {
                return stripHTML(String(rowHTML[cellRange]))
            }
            return nil
        }
    }

    private static func stripHTML(_ text: String) -> String {
        var result = text
        let tagPattern = try! NSRegularExpression(pattern: "<[^>]+>", options: [])
        result = tagPattern.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: " "
        )
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&#160;", with: " ")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractTitle(from html: String) -> String {
        let patterns = [
            "<h1[^>]*>(.*?)</h1>",
            "<title[^>]*>(.*?)</title>"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let title = stripHTML(String(html[range]))
                    .replacingOccurrences(of: "Scorecard", with: "")
                    .replacingOccurrences(of: "scorecard", with: "")
                    .replacingOccurrences(of: "Score Card", with: "")
                    .replacingOccurrences(of: " - ", with: "")
                    .replacingOccurrences(of: " | ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty && title.count < 80 { return title }
            }
        }
        return ""
    }

    // MARK: - Table Parsing

    private static let teeKeywords: Set<String> = [
        "black", "blue", "white", "gold", "silver", "red",
        "green", "orange", "champion", "tips", "yellow",
        "copper", "maroon", "combo", "tournament"
    ]

    private static func parseTable(_ table: [[String]]) -> ParsedCourseData? {
        guard table.count >= 2 else { return nil }

        var holeNumberRow: [Int]?
        var parRow: [Int]?
        var hdcpRow: [Int]?
        var teeRows: [(name: String, yardages: [Int])] = []
        var holeIndices: [Int] = []

        for row in table {
            guard row.count >= 9 else { continue }
            let label = row.first?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cells = row.dropFirst().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            let numbers = cells.compactMap { Int($0.replacingOccurrences(of: ",", with: "")) }

            // Hole number row
            if label.contains("hole") || (numbers == Array(1...numbers.count) && numbers.count >= 9) {
                let holeNums = cells.compactMap { Int($0) }.filter { (1...18).contains($0) }
                if holeNums.count >= 9 {
                    holeNumberRow = holeNums
                    holeIndices = cells.enumerated().compactMap { i, cell in
                        if let n = Int(cell), (1...18).contains(n) { return i }
                        return nil
                    }
                }
                continue
            }

            let filteredNumbers: [Int]
            if !holeIndices.isEmpty {
                filteredNumbers = holeIndices.compactMap { i in
                    i < cells.count ? Int(cells[i].replacingOccurrences(of: ",", with: "")) : nil
                }
            } else {
                filteredNumbers = filterTotals(numbers)
            }

            guard filteredNumbers.count >= 9 else { continue }

            // Par row
            if label.contains("par") {
                parRow = filteredNumbers.filter { (3...5).contains($0) }
                continue
            }

            // Handicap row
            if label.contains("hcp") || label.contains("hdcp") || label.contains("handicap") {
                let isLadies = label.contains("ladies") || label.contains("women")
                    || label.hasPrefix("l ") || label.hasPrefix("w ")
                if !isLadies && hdcpRow == nil {
                    hdcpRow = filteredNumbers.filter { (1...18).contains($0) }
                }
                continue
            }

            // Tee/yardage row — label matches a tee color
            let labelWords = Set(label.components(separatedBy: .whitespaces))
            if let teeName = labelWords.first(where: { teeKeywords.contains($0) }) {
                let yds = filteredNumbers.filter { (50...700).contains($0) }
                if yds.count >= 9 {
                    teeRows.append((name: teeName.capitalized, yardages: yds))
                    continue
                }
            }

            // Unlabeled: try to infer type from values
            if parRow == nil && filteredNumbers.allSatisfy({ (3...5).contains($0) }) {
                parRow = filteredNumbers
            } else if filteredNumbers.allSatisfy({ (50...700).contains($0) }) {
                let name = labelWords.first(where: { teeKeywords.contains($0) })?.capitalized
                    ?? label.capitalized.trimmingCharacters(in: .whitespacesAndNewlines)
                let teeName = name.isEmpty ? "Tee \(teeRows.count + 1)" : name
                teeRows.append((name: teeName, yardages: filteredNumbers))
            } else if hdcpRow == nil && filteredNumbers.allSatisfy({ (1...18).contains($0) }) {
                let isSequential = filteredNumbers == Array(1...filteredNumbers.count)
                if !isSequential {
                    hdcpRow = filteredNumbers
                }
            }
        }

        guard parRow != nil || !teeRows.isEmpty else { return nil }

        let holeCount = parRow?.count ?? teeRows.first?.yardages.count ?? 18
        var holes: [ParsedCourseData.ParsedHole] = []

        for i in 0..<holeCount {
            var yardages: [String: Int] = [:]
            for teeRow in teeRows {
                if i < teeRow.yardages.count {
                    yardages[teeRow.name] = teeRow.yardages[i]
                }
            }
            holes.append(.init(
                number: holeNumberRow != nil && i < holeNumberRow!.count ? holeNumberRow![i] : i + 1,
                par: parRow != nil && i < parRow!.count ? parRow![i] : 4,
                hdcp: hdcpRow != nil && i < hdcpRow!.count ? hdcpRow![i] : i + 1,
                yardages: yardages
            ))
        }

        let teeNames = teeRows.map { $0.name }
        return ParsedCourseData(name: "", holes: holes, teeNames: teeNames)
    }

    private static func filterTotals(_ numbers: [Int]) -> [Int] {
        if numbers.count == 9 || numbers.count == 18 { return numbers }
        if numbers.count == 10 { return Array(numbers.prefix(9)) }
        if numbers.count == 21 {
            return Array(numbers[0..<9]) + Array(numbers[10..<19])
        }
        if numbers.count == 20 {
            return Array(numbers[0..<9]) + Array(numbers[10..<19])
        }
        return numbers
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
