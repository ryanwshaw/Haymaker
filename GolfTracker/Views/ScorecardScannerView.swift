import SwiftUI
import PhotosUI
import Vision

struct ScorecardScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var scorecardImage: UIImage?
    @State private var isProcessing = false
    @State private var parsedCourse: ParsedCourseData?
    @State private var showReview = false

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
        }
    }

    // MARK: - Upload Prompt

    private var uploadPrompt: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.fairwayGreen)

            Text("Scan a Scorecard")
                .font(.title2.bold())

            Text("Upload a photo of a golf course scorecard and we'll extract the hole data automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.headline)
                    Text("Choose Photo")
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
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadImage(from: newItem) }
            }

            Spacer()
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
    static func parse(texts: [(String, CGRect)]) -> ParsedCourseData {
        let sortedByY = texts.sorted { $0.1.origin.y > $1.1.origin.y }

        var courseName = ""
        var teeNames: [String] = []
        var holes: [ParsedCourseData.ParsedHole] = []

        let allText = texts.map(\.0)

        // Try to find course name (usually top-most large text)
        if let topText = sortedByY.first?.0, !topText.isEmpty {
            let cleaned = topText.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.count > 2 && !cleaned.allSatisfy(\.isNumber) {
                courseName = cleaned
            }
        }

        let knownTeeColors = ["black", "blue", "white", "gold", "silver", "red",
                               "green", "orange", "champion", "tips", "back", "forward",
                               "senior", "ladies", "family", "men", "women"]
        for text in allText {
            let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if knownTeeColors.contains(lower) && !teeNames.contains(text.capitalized) {
                teeNames.append(text.capitalized)
            }
        }

        // Group text by rows (similar Y coordinates)
        let rows = groupIntoRows(texts)

        // Look for rows of numbers that could be par values (all 3, 4, or 5)
        var parRow: [Int]?
        var hdcpRow: [Int]?
        var teeYardageRows: [[Int]] = []

        for row in rows {
            let numbers = row.compactMap { Int($0.0) }
            if numbers.count >= 9 {
                if numbers.allSatisfy({ $0 >= 3 && $0 <= 5 }) && parRow == nil {
                    parRow = numbers
                } else if numbers.allSatisfy({ $0 >= 1 && $0 <= 18 }) && numbers.count <= 18 {
                    if numbers == Array(1...numbers.count) || numbers == Array(1...9) || numbers == Array(10...18) {
                        continue
                    }
                    hdcpRow = numbers
                } else if numbers.allSatisfy({ $0 >= 50 && $0 <= 700 }) {
                    teeYardageRows.append(numbers)
                }
            }
        }

        let holeCount = parRow?.count ?? 18
        for i in 0..<holeCount {
            var yardages: [String: Int] = [:]
            for (ti, yardageRow) in teeYardageRows.enumerated() {
                let teeName = ti < teeNames.count ? teeNames[ti] : "Tee \(ti + 1)"
                if i < yardageRow.count {
                    yardages[teeName] = yardageRow[i]
                }
            }

            holes.append(ParsedCourseData.ParsedHole(
                number: i + 1,
                par: (parRow != nil && i < parRow!.count) ? parRow![i] : 4,
                hdcp: (hdcpRow != nil && i < hdcpRow!.count) ? hdcpRow![i] : i + 1,
                yardages: yardages
            ))
        }

        if teeNames.isEmpty && !teeYardageRows.isEmpty {
            teeNames = (0..<teeYardageRows.count).map { "Tee \($0 + 1)" }
        }

        if holes.isEmpty {
            holes = (1...18).map {
                ParsedCourseData.ParsedHole(number: $0, par: 4, hdcp: $0, yardages: [:])
            }
        }

        return ParsedCourseData(name: courseName, holes: holes, teeNames: teeNames)
    }

    private static func groupIntoRows(_ texts: [(String, CGRect)]) -> [[(String, CGRect)]] {
        let sorted = texts.sorted { $0.1.origin.y > $1.1.origin.y }
        var rows: [[(String, CGRect)]] = []
        var currentRow: [(String, CGRect)] = []
        var currentY: CGFloat = -1

        let threshold: CGFloat = 0.015

        for item in sorted {
            if currentY < 0 {
                currentY = item.1.origin.y
                currentRow = [item]
            } else if abs(item.1.origin.y - currentY) < threshold {
                currentRow.append(item)
            } else {
                if !currentRow.isEmpty {
                    rows.append(currentRow.sorted { $0.1.origin.x < $1.1.origin.x })
                }
                currentRow = [item]
                currentY = item.1.origin.y
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow.sorted { $0.1.origin.x < $1.1.origin.x })
        }

        return rows
    }
}
