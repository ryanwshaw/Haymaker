import SwiftUI
import SwiftData

struct ActiveRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var round: Round
    var onDismiss: () -> Void

    @State private var currentHoleIndex = 0
    @State private var showDiscardConfirm = false
    @State private var showFinishConfirm = false
    @State private var showMiniScorecard = false
    @State private var activeBadge: BadgeType? = nil
    @ObservedObject private var badgeManager = BadgeManager.shared

    private var sortedScores: [HoleScore] { round.sortedScores }
    private var playedCount: Int { sortedScores.filter { !$0.teeResultRaw.isEmpty }.count }

    var body: some View {
        ZStack {
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
                    progressBar
                    holePicker
                    HoleEntryView(score: sortedScores[currentHoleIndex], round: round) { submittedScore in
                        submitCurrentHole(submittedScore)
                    }
                    miniScorecardBar
                    }
                }
                .background(Color(.systemGroupedBackground))
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    if currentHoleIndex >= sortedScores.count && !sortedScores.isEmpty {
                        currentHoleIndex = 0
                    }
                    badgeManager.resetSession()
                }
                .onChange(of: badgeManager.pendingBadge) { _, badge in
                    if let badge {
                        activeBadge = badge
                        badgeManager.clearPending()
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
                        VStack(spacing: 0) {
                            Text("Hole \(currentHoleIndex + 1) of \(sortedScores.count)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text("\(round.teeRaw) · \(round.courseName)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !sortedScores.isEmpty {
                        Button {
                            if playedCount < sortedScores.count {
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

            if let badge = activeBadge {
                BadgePopupView(badgeType: badge) {
                    activeBadge = nil
                }
                .zIndex(100)
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

        let roundToPublish = round
        Task { await CloudKitManager.shared.publishRound(roundToPublish) }

        onDismiss()
    }

    private func submitCurrentHole(_ submittedScore: HoleScore) {
        badgeManager.checkForBadges(
            score: submittedScore,
            allScores: sortedScores,
            currentIndex: currentHoleIndex,
            round: round
        )

        try? modelContext.save()

        if currentHoleIndex < sortedScores.count - 1 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentHoleIndex += 1
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = sortedScores.isEmpty ? 0 : CGFloat(playedCount) / CGFloat(sortedScores.count)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppTheme.darkGreen.opacity(0.3))
                Rectangle()
                    .fill(AppTheme.gold)
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(response: 0.4), value: playedCount)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Hole Picker

    private var holePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(sortedScores.enumerated()), id: \.element.id) { i, score in
                        holePickerCell(index: i, score: score)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .onChange(of: currentHoleIndex) { _, newValue in
                withAnimation(.spring(response: 0.3)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func holePickerCell(index i: Int, score: HoleScore) -> some View {
        let isCurrent = currentHoleIndex == i
        let hasData = !score.teeResultRaw.isEmpty
        let toPar = score.score - score.par

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentHoleIndex = i
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 1) {
                Text("\(score.holeNumber)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isCurrent ? .white.opacity(0.6) : .secondary)
                if hasData {
                    Text("\(score.score)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(isCurrent ? .white : AppTheme.scoreColor(toPar))
                } else {
                    Text("·")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isCurrent ? .white.opacity(0.4) : Color.gray.opacity(0.4))
                }
            }
            .frame(width: 34, height: 40)
            .background(cellBackground(isCurrent: isCurrent, hasData: hasData, toPar: toPar),
                         in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                isCurrent
                    ? RoundedRectangle(cornerRadius: 8).stroke(AppTheme.gold, lineWidth: 2)
                    : nil
            )
            .scaleEffect(isCurrent ? 1.08 : 1.0)
            .animation(.spring(response: 0.25), value: isCurrent)
        }
        .buttonStyle(.plain)
        .id(i)
    }

    private func cellBackground(isCurrent: Bool, hasData: Bool, toPar: Int) -> Color {
        if isCurrent { return AppTheme.fairwayGreen }
        if hasData {
            return AppTheme.scoreColor(toPar).opacity(0.12)
        }
        return Color(.systemGray6)
    }

    // MARK: - Mini Scorecard Bar

    private var miniScorecardBar: some View {
        let front9 = sortedScores.prefix(min(9, sortedScores.count))
        let back9 = sortedScores.count > 9 ? Array(sortedScores.suffix(from: 9)) : []
        let front9Score = front9.filter { !$0.teeResultRaw.isEmpty }.map(\.score).reduce(0, +)
        let back9Score = back9.filter { !$0.teeResultRaw.isEmpty }.map(\.score).reduce(0, +)
        let front9Par = front9.map(\.par).reduce(0, +)
        let back9Par = back9.map(\.par).reduce(0, +)
        let totalScore = front9Score + back9Score
        let totalPar = front9Par + back9Par

        return VStack(spacing: 0) {
            Divider()
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showMiniScorecard.toggle()
                }
                Haptics.light()
            } label: {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("OUT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("\(front9Score)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                    }
                    if !back9.isEmpty {
                        HStack(spacing: 4) {
                            Text("IN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("\(back9Score)")
                                .font(.system(size: 14, weight: .bold).monospacedDigit())
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("TOT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("\(totalScore)")
                            .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                        if totalScore != totalPar {
                            let diff = totalScore - totalPar
                            Text(diff > 0 ? "+\(diff)" : "\(diff)")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundStyle(AppTheme.scoreColor(diff))
                        }
                    }

                    Image(systemName: showMiniScorecard ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if showMiniScorecard {
                expandedScorecard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(.ultraThinMaterial)
    }

    private var expandedScorecard: some View {
        VStack(spacing: 3) {
            let half = min(9, sortedScores.count)
            miniScorecardRow(label: "OUT", scores: Array(sortedScores.prefix(half)))
            if sortedScores.count > 9 {
                miniScorecardRow(label: "IN", scores: Array(sortedScores.suffix(from: 9)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func miniScorecardRow(label: String, scores: [HoleScore]) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
            ForEach(Array(scores.enumerated()), id: \.element.id) { _, score in
                let hasData = !score.teeResultRaw.isEmpty
                let toPar = score.score - score.par
                Text(hasData ? "\(score.score)" : "·")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(hasData ? (toPar == 0 ? .primary : .white) : Color.gray.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                    .background(hasData ? AppTheme.scoreColor(toPar).opacity(toPar == 0 ? 0.08 : 0.85) : Color(.systemGray6),
                                in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
