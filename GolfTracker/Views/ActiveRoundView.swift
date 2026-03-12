import SwiftUI
import SwiftData

struct ActiveRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var round: Round
    var onDismiss: () -> Void

    @State private var currentHoleIndex = 0
    @State private var showDiscardConfirm = false
    @State private var showFinishConfirm = false

    private var sortedScores: [HoleScore] { round.sortedScores }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if sortedScores.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No hole data")
                            .font(.headline)
                        Text("Discard this round and start a new one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    holePicker
                    HoleEntryView(score: sortedScores[currentHoleIndex], round: round)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if currentHoleIndex >= sortedScores.count && !sortedScores.isEmpty {
                    currentHoleIndex = 0
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button {
                            try? modelContext.save()
                            Haptics.success()
                            onDismiss()
                        } label: {
                            Label("Save & exit", systemImage: "square.and.arrow.down")
                        }
                        Button(role: .destructive) {
                            showDiscardConfirm = true
                        } label: {
                            Label("Discard round", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body.bold())
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    if !sortedScores.isEmpty {
                        let score = sortedScores[currentHoleIndex]
                        let info = score.courseHoleInfo()
                        VStack(spacing: 0) {
                            Text(info.name.isEmpty ? "Hole \(info.number)" : info.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text("\(round.teeRaw) · \(info.yardage(for: round.teeRaw)) yds")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !sortedScores.isEmpty {
                        Button {
                            let played = sortedScores.filter { !$0.teeResultRaw.isEmpty }
                            if played.count < sortedScores.count {
                                showFinishConfirm = true
                            } else {
                                finishRound()
                            }
                        } label: {
                            Text("Finish")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.darkGreen)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(AppTheme.gold, in: Capsule())
                        }
                    }
                }
            }
            .toolbarBackground(AppTheme.darkGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Discard this round?", isPresented: $showDiscardConfirm) {
                Button("Discard", role: .destructive) {
                    modelContext.delete(round)
                    try? modelContext.save()
                    Haptics.medium()
                    onDismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete this round and all hole data.")
            }
            .alert("Finish round?", isPresented: $showFinishConfirm) {
                Button("Finish") { finishRound() }
                Button("Cancel", role: .cancel) { }
            } message: {
                let played = sortedScores.filter { !$0.teeResultRaw.isEmpty }.count
                Text("You've logged \(played) of \(sortedScores.count) holes. Unplayed holes will be removed.")
            }
        }
    }

    private func finishRound() {
        let unplayed = sortedScores.filter { $0.teeResultRaw.isEmpty }
        for score in unplayed {
            modelContext.delete(score)
        }
        round.isComplete = true
        try? modelContext.save()
        Haptics.success()
        onDismiss()
    }

    // MARK: - Hole Picker

    private var holePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(sortedScores.enumerated()), id: \.element.id) { i, score in
                        holePickerButton(index: i, score: score)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .onChange(of: currentHoleIndex) { _, newValue in
                withAnimation(.spring(response: 0.3)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func holePickerButton(index i: Int, score: HoleScore) -> some View {
        let isCurrent = currentHoleIndex == i
        let hasData = !score.teeResultRaw.isEmpty
        let toPar = score.score - score.par

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentHoleIndex = i
            }
            Haptics.selection()
        } label: {
            holePickerLabel(holeNumber: score.holeNumber, displayScore: score.score,
                            hasData: hasData, isCurrent: isCurrent, toPar: toPar)
        }
        .buttonStyle(.plain)
        .id(i)
    }

    private func holePickerLabel(holeNumber: Int, displayScore: Int,
                                  hasData: Bool, isCurrent: Bool, toPar: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(holeNumber)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            if hasData {
                Text("\(displayScore)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isCurrent ? .white.opacity(0.8) : AppTheme.scoreColor(toPar))
            } else {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(isCurrent ? .white.opacity(0.5) : Color.gray.opacity(0.5))
            }
        }
        .frame(width: 38, height: 42)
        .background(holePickerBackground(isCurrent: isCurrent, hasData: hasData),
                     in: RoundedRectangle(cornerRadius: 10))
        .overlay(isCurrent ? RoundedRectangle(cornerRadius: 10).stroke(AppTheme.gold, lineWidth: 2) : nil)
        .foregroundColor(isCurrent ? .white : .primary)
    }

    private func holePickerBackground(isCurrent: Bool, hasData: Bool) -> Color {
        if isCurrent { return AppTheme.fairwayGreen }
        if hasData { return AppTheme.fairwayGreen.opacity(0.08) }
        return Color(.systemGray6)
    }
}
