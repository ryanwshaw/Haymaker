import SwiftUI
import SwiftData

struct ActiveRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var round: Round
    var match: Match?
    var onMatchFinished: ((Match) -> Void)?
    var onDismiss: () -> Void

    @State private var currentHoleIndex = 0
    @State private var showDiscardConfirm = false
    @State private var showFinishConfirm = false
    @State private var showMiniScorecard = false
    @State private var activeBadge: BadgeType? = nil
    @State private var showConfetti = false
    @ObservedObject private var badgeManager = BadgeManager.shared

    @Query private var allHoleScores: [HoleScore]

    @State private var wolfChoices: [Int: WolfChoice] = [:]
    @State private var isDismissing = false

    private var sortedScores: [HoleScore] { round.sortedScores }
    private var isMatchOnly: Bool { match != nil && match?.logPersonalStats == false }
    private var playedCount: Int {
        if isMatchOnly {
            return match?.userPlayer?.holesPlayed ?? 0
        }
        return sortedScores.filter { !$0.teeResultRaw.isEmpty }.count
    }

    @State private var loadTimedOut = false

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    if isDismissing {
                        Spacer()
                        ProgressView().controlSize(.large)
                        Spacer()
                    } else if sortedScores.isEmpty && !loadTimedOut {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Loading holes...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else if sortedScores.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.gold)
                            Text("No Holes Found")
                                .font(.headline)
                            Text("This course doesn't have any holes set up. Try scanning the scorecard first.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button("Close") { onDismiss() }
                                .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    } else {
                    progressBar
                    holePicker

                    if let match {
                        MatchScoreboardView(
                            match: match,
                            wolfChoices: wolfChoices,
                            currentHole: sortedScores[currentHoleIndex].holeNumber
                        )

                        handicapStrokeBanner(match: match, holeScore: sortedScores[currentHoleIndex])
                    }

                    if isMatchOnly, let match {
                        MatchOnlyHoleView(
                            match: match,
                            holeScore: sortedScores[currentHoleIndex],
                            wolfChoices: $wolfChoices
                        ) {
                            submitMatchOnlyHole()
                        }
                    } else {
                        HoleEntryView(score: sortedScores[currentHoleIndex], round: round) { submittedScore in
                            submitCurrentHole(submittedScore)
                        }

                        if let match {
                            MatchHoleOverlay(
                                match: match,
                                holeNumber: sortedScores[currentHoleIndex].holeNumber,
                                holePar: sortedScores[currentHoleIndex].par,
                                wolfChoices: $wolfChoices
                            )
                            .padding(.top, 4)
                        }
                    }

                    miniScorecardBar
                    }
                }
                .background(Color(.systemGroupedBackground))
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    badgeManager.resetSession()
                    if !sortedScores.isEmpty {
                        setDefaultMatchScores()
                    }
                }
                .onChange(of: currentHoleIndex) { _, _ in
                    setDefaultMatchScores()
                }
                .onChange(of: badgeManager.pendingBadge) { _, badge in
                    if let badge {
                        activeBadge = badge
                        badgeManager.clearPending()
                        if badge == .fullCard {
                            showConfetti = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                                showConfetti = false
                            }
                        }
                    }
                }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button {
                            isDismissing = true
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
                            if let match {
                                Text("\(match.gameType.displayName) · \(round.courseName)")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                            } else {
                                Text("\(round.teeRaw) · \(round.courseName)")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
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
                    isDismissing = true
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

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(99)
            }
        }
        .task { await waitForScores() }
    }

    private func finishRound() {
        isDismissing = true
        if isMatchOnly {
            // In match-only mode, sync scores from MatchPlayer → HoleScores so the round has valid totals
            if let userPlayer = match?.userPlayer {
                for hs in sortedScores {
                    if let matchScore = userPlayer.score(for: hs.holeNumber) {
                        hs.score = matchScore
                        hs.teeResultRaw = "matchOnly"
                    }
                }
            }
            let stillEmpty = sortedScores.filter { $0.teeResultRaw.isEmpty }
            for score in stillEmpty {
                modelContext.delete(score)
            }
        } else {
            let unplayed = sortedScores.filter { $0.teeResultRaw.isEmpty }
            for score in unplayed {
                modelContext.delete(score)
            }
            if let userPlayer = match?.userPlayer {
                for score in sortedScores where !score.teeResultRaw.isEmpty {
                    userPlayer.setScore(score.score, for: score.holeNumber)
                }
            }
        }

        round.isComplete = true
        match?.isComplete = true
        if match?.gameType == .wolf {
            match?.wolfChoices = wolfChoices
        }

        try? modelContext.save()
        Haptics.success()

        if let match {
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onMatchFinished?(match)
            }
        } else {
            onDismiss()
        }
    }

    private func waitForScores() async {
        for _ in 0..<15 {
            if !sortedScores.isEmpty {
                setDefaultMatchScores()
                return
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        // After 3s, give up waiting — show the no-holes error state
        loadTimedOut = true
    }

    private func setDefaultMatchScores() {
        guard !isDismissing, let match, !sortedScores.isEmpty else { return }
        let holeIndex = min(currentHoleIndex, sortedScores.count - 1)
        let hole = sortedScores[holeIndex]
        let par = hole.par

        for player in match.sortedPlayers {
            if player.score(for: hole.holeNumber) == nil {
                player.setScore(par, for: hole.holeNumber)
            }
        }
    }

    private func submitMatchOnlyHole() {
        if let match, let userPlayer = match.userPlayer {
            let holeNum = sortedScores[currentHoleIndex].holeNumber
            let score = userPlayer.score(for: holeNum) ?? sortedScores[currentHoleIndex].par
            sortedScores[currentHoleIndex].score = score
            sortedScores[currentHoleIndex].teeResultRaw = "matchOnly"
        }
        try? modelContext.save()

        if currentHoleIndex < sortedScores.count - 1 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentHoleIndex += 1
            }
        }
    }

    private func courseHistoricalScores() -> [HoleScore] {
        let currentRoundID = round.id
        let courseName = round.courseName
        return allHoleScores.filter { hs in
            guard let r = hs.round else { return false }
            return r.isComplete && r.id != currentRoundID && r.courseName == courseName
        }
    }

    private func submitCurrentHole(_ submittedScore: HoleScore) {
        badgeManager.checkForBadges(
            score: submittedScore,
            allScores: sortedScores,
            currentIndex: currentHoleIndex,
            round: round,
            courseHistoricalScores: courseHistoricalScores()
        )

        if let match, let userPlayer = match.userPlayer {
            userPlayer.setScore(submittedScore.score, for: submittedScore.holeNumber)
        }

        try? modelContext.save()

        if currentHoleIndex < sortedScores.count - 1 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentHoleIndex += 1
            }
        }
    }

    // MARK: - Handicap Stroke Banner

    private func handicapStrokeBanner(match: Match, holeScore: HoleScore) -> some View {
        let ranking = holeScore.holeMensHdcp
        let playersWithStrokes = match.sortedPlayers.compactMap { player -> (MatchPlayer, Int)? in
            let strokes = MatchScoring.handicapStrokes(playerHandicap: player.handicapStrokes, holeRanking: ranking)
            return strokes > 0 ? (player, strokes) : nil
        }

        return Group {
            if !playersWithStrokes.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(AppTheme.fairwayGreen)
                    Text("Strokes this hole:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(playersWithStrokes, id: \.0.id) { player, strokes in
                        HStack(spacing: 3) {
                            Text(player.name.components(separatedBy: " ").first ?? player.name)
                                .font(.system(size: 11, weight: .bold))
                            HStack(spacing: 1) {
                                ForEach(0..<strokes, id: \.self) { _ in
                                    Circle()
                                        .fill(AppTheme.fairwayGreen)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(AppTheme.fairwayGreen.opacity(0.08))
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

    private func holeHasData(_ score: HoleScore) -> Bool {
        if isMatchOnly {
            return match?.userPlayer?.score(for: score.holeNumber) != nil
        }
        return !score.teeResultRaw.isEmpty
    }

    private func holePickerCell(index i: Int, score: HoleScore) -> some View {
        let isCurrent = currentHoleIndex == i
        let hasData = holeHasData(score)
        let displayScore = isMatchOnly ? (match?.userPlayer?.score(for: score.holeNumber) ?? score.par) : score.score
        let toPar = displayScore - score.par

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
                    Text("\(displayScore)")
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
        let front9Score: Int = {
            if isMatchOnly, let up = match?.userPlayer {
                return front9.compactMap { up.score(for: $0.holeNumber) }.reduce(0, +)
            }
            return front9.filter { !$0.teeResultRaw.isEmpty }.map(\.score).reduce(0, +)
        }()
        let back9Score: Int = {
            if isMatchOnly, let up = match?.userPlayer {
                return back9.compactMap { up.score(for: $0.holeNumber) }.reduce(0, +)
            }
            return back9.filter { !$0.teeResultRaw.isEmpty }.map(\.score).reduce(0, +)
        }()
        // Only count par for holes that have been completed
        let front9Par: Int = {
            if isMatchOnly, let up = match?.userPlayer {
                return front9.filter { up.score(for: $0.holeNumber) != nil }.map(\.par).reduce(0, +)
            }
            return front9.filter { !$0.teeResultRaw.isEmpty }.map(\.par).reduce(0, +)
        }()
        let back9Par: Int = {
            if isMatchOnly, let up = match?.userPlayer {
                return back9.filter { up.score(for: $0.holeNumber) != nil }.map(\.par).reduce(0, +)
            }
            return back9.filter { !$0.teeResultRaw.isEmpty }.map(\.par).reduce(0, +)
        }()
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
                        if totalScore > 0 {
                            let diff = totalScore - totalPar
                            Text(diff == 0 ? "E" : diff > 0 ? "+\(diff)" : "\(diff)")
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
                let hasData = holeHasData(score)
                let displayScore = isMatchOnly ? (match?.userPlayer?.score(for: score.holeNumber) ?? score.par) : score.score
                let toPar = displayScore - score.par
                Text(hasData ? "\(displayScore)" : "·")
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

// MARK: - Confetti

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let xDrift: CGFloat
    let size: CGFloat
    let color: Color
    let delay: Double
    let duration: Double
    let rotations: Double
    let shape: ParticleShape

    enum ParticleShape: CaseIterable { case rect, circle, ribbon }
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var fallen: [UUID: Bool] = [:]

    private let colors: [Color] = [
        Color(red: 0.31, green: 0.53, blue: 0.38),
        Color(red: 0.78, green: 0.68, blue: 0.73),
        Color(red: 0.76, green: 0.63, blue: 0.30),
        .white,
        Color(red: 0.18, green: 0.48, blue: 0.70),
        Color(red: 0.92, green: 0.35, blue: 0.35),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(particles) { p in
                    particleView(p)
                        .position(
                            x: w * p.startX + (fallen[p.id] == true ? p.xDrift * w * 0.25 : 0),
                            y: fallen[p.id] == true ? h + 60 : -40
                        )
                        .rotationEffect(.degrees(fallen[p.id] == true ? p.rotations * 360 : 0))
                        .opacity(fallen[p.id] == true ? 0 : 1)
                        .animation(
                            .timingCurve(0.2, 0.8, 0.6, 1.0, duration: p.duration).delay(p.delay),
                            value: fallen[p.id]
                        )
                }
            }
            .onAppear {
                particles = makeParticles()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    for p in particles { fallen[p.id] = true }
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func particleView(_ p: ConfettiParticle) -> some View {
        switch p.shape {
        case .rect:
            Rectangle().fill(p.color).frame(width: p.size, height: p.size * 0.5)
        case .circle:
            Circle().fill(p.color).frame(width: p.size * 0.6, height: p.size * 0.6)
        case .ribbon:
            Capsule().fill(p.color).frame(width: p.size * 1.4, height: p.size * 0.3)
        }
    }

    private func makeParticles() -> [ConfettiParticle] {
        let shapes = ConfettiParticle.ParticleShape.allCases
        return (0..<90).map { i in
            ConfettiParticle(
                startX: CGFloat.random(in: 0...1),
                xDrift: CGFloat.random(in: -0.4...0.4),
                size: CGFloat.random(in: 8...16),
                color: colors[i % colors.count],
                delay: Double.random(in: 0...1.2),
                duration: Double.random(in: 2.2...3.8),
                rotations: Double.random(in: 2...6) * (Bool.random() ? 1 : -1),
                shape: shapes[i % shapes.count]
            )
        }
    }
}
