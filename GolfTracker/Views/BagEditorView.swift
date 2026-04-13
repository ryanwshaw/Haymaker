import SwiftUI
import UniformTypeIdentifiers

struct BagEditorView: View {
    @ObservedObject private var bag = BagManager.shared
    @State private var showImporter = false
    @State private var importResult: String?
    @State private var showImportAlert = false

    var body: some View {
        List {
            Section {
                Button {
                    showImporter = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.mauve, in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import from Launch Monitor")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("CSV from Trackman, GCQuad, Mevo+, etc.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.quaternary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Import")
            }

            Section {
                ForEach(Club.allCases, id: \.rawValue) { club in
                    HStack(spacing: 14) {
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                bag.toggle(club)
                            }
                            Haptics.selection()
                        } label: {
                            Image(systemName: bag.clubs.contains(club) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(bag.clubs.contains(club) ? AppTheme.fairwayGreen : Color(.systemGray3))
                        }
                        .buttonStyle(.plain)

                        Text(club.displayName)
                            .font(.body)
                            .foregroundStyle(bag.clubs.contains(club) ? .primary : .secondary)

                        Spacer()

                        if bag.clubs.contains(club) && club != .putter {
                            YardageField(club: club, bag: bag)
                        }
                    }
                }
            } header: {
                Text("Clubs & average yardages")
            } footer: {
                Text("\(bag.clubs.count) clubs · set your average carry yardage so the app can auto-select clubs based on distance")
            }
        }
        .navigationTitle("My Bag")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let csvText = try? String(contentsOf: url, encoding: .utf8) {
                    let count = bag.importFromCSV(csvText)
                    importResult = count > 0
                        ? "\(count) club\(count == 1 ? "" : "s") imported with yardages."
                        : "No matching clubs found. Make sure your CSV has 'Club' and 'Carry' or 'Distance' columns."
                    Haptics.success()
                } else {
                    importResult = "Could not read the file."
                }
                showImportAlert = true
            case .failure:
                importResult = "Import cancelled."
                showImportAlert = true
            }
        }
        .alert("Import Complete", isPresented: $showImportAlert) {
            Button("OK") { }
        } message: {
            Text(importResult ?? "")
        }
    }
}

private struct YardageField: View {
    let club: Club
    @ObservedObject var bag: BagManager
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField("—", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 44)
                .focused($focused)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commitValue() }
                }
            Text("yds")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            if let yds = bag.clubYardages[club] {
                text = "\(yds)"
            }
        }
    }

    private func commitValue() {
        if let val = Int(text), val > 0 {
            bag.clubYardages[club] = val
        } else if text.isEmpty {
            bag.clubYardages.removeValue(forKey: club)
        }
    }
}
