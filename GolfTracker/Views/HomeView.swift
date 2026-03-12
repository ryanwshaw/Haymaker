import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \Course.createdAt) private var courses: [Course]

    @State private var activeRound: Round?
    @State private var showActiveRound = false
    @State private var showTeeSelector = false
    @State private var selectedCourse: Course?

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }
    private var incompleteRounds: [Round] { allRounds.filter { !$0.isComplete } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                VStack(spacing: 16) {
                    if let active = incompleteRounds.first {
                        inProgressCard(active)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    newRoundButton

                    if !completedRounds.isEmpty {
                        lastRoundCard
                        trendCard
                        completedSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showActiveRound, onDismiss: {
            activeRound = nil
        }) {
            if let round = activeRound {
                ActiveRoundView(round: round) { showActiveRound = false }
            }
        }
        .sheet(isPresented: $showTeeSelector) {
            if let course = selectedCourse ?? courses.first {
                TeeSelectionView(course: course) { teeName in
                    showTeeSelector = false
                    createRound(course: course, teeName: teeName)
                }
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 10) {
            if completedRounds.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.gold)
                    Text("Ready to play?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                heroStats
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [AppTheme.darkGreen, AppTheme.fairwayGreen, AppTheme.darkGreen.opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private var heroStats: some View {
        let full18 = completedRounds.filter(\.hasFull18)
        let avg18: String = full18.isEmpty ? "—" : String(format: "%.0f", Double(full18.map(\.totalScore).reduce(0, +)) / Double(full18.count))
        let best: String = full18.isEmpty ? "—" : "\(full18.map(\.totalScore).min() ?? 0)"
        let avgPutts = Double(completedRounds.map(\.totalPutts).reduce(0, +)) / Double(completedRounds.count)

        return HStack(spacing: 0) {
            heroStat(value: avg18, label: "AVG 18")
            heroDivider
            heroStat(value: best, label: "BEST")
            heroDivider
            heroStat(value: String(format: "%.0f", avgPutts), label: "PUTTS")
            heroDivider
            heroStat(value: "\(completedRounds.count)", label: "ROUNDS")
        }
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AppTheme.gold)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    // MARK: - In Progress Card

    private func inProgressCard(_ round: Round) -> some View {
        Button {
            Haptics.medium()
            openRound(round)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.fairwayGreen)
                        .frame(width: 44, height: 44)
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue round")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Circle().fill(round.displayTeeColor).frame(width: 8, height: 8)
                        Text("\(round.teeRaw) · \(round.courseName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.fairwayGreen.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: AppTheme.fairwayGreen.opacity(0.1), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - New Round Button

    private var newRoundButton: some View {
        Button {
            Haptics.medium()
            handlePlusTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.headline)
                Text("New round")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                LinearGradient(colors: [AppTheme.fairwayGreen, AppTheme.darkGreen], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            )
            .shadow(color: AppTheme.fairwayGreen.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Last Round Card

    private var lastRoundCard: some View {
        let last = completedRounds[0]
        let scores = last.sortedScores
        let pars = scores.map(\.par)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last round")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(last.displayTeeColor).frame(width: 7, height: 7)
                    Text(last.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(last.totalScore)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                Text(last.scoreToParString)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.scoreColor(last.scoreToPar))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    miniStatPill(icon: "flag.fill", value: String(format: "%.0f%%", last.fairwayPct), label: "FWY")
                    miniStatPill(icon: "circle.fill", value: String(format: "%.0f%%", last.girPct), label: "GIR")
                    miniStatPill(icon: "smallcircle.filled.circle", value: "\(last.totalPutts)", label: "PUTTS")
                }
            }

            miniScorecard(scores: scores, par: pars)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }

    private func miniStatPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func miniScorecard(scores: [HoleScore], par: [Int]) -> some View {
        VStack(spacing: 3) {
            let half = scores.count / 2
            if half > 0 {
                miniScorecardRow(label: "OUT", scores: Array(scores.prefix(half)), pars: Array(par.prefix(half)))
                miniScorecardRow(label: "IN", scores: Array(scores.suffix(scores.count - half)), pars: Array(par.suffix(scores.count - half)))
            }
        }
    }

    private func miniScorecardRow(label: String, scores: [HoleScore], pars: [Int]) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
            ForEach(Array(scores.enumerated()), id: \.element.holeNumber) { i, score in
                let toPar = i < pars.count ? score.score - pars[i] : 0
                Text("\(score.score)")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(colorForToPar(toPar))
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                    .background(backgroundForToPar(toPar), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func colorForToPar(_ toPar: Int) -> Color {
        switch toPar {
        case ...(-2): return .white
        case -1: return .white
        case 0: return .primary
        case 1: return .white
        default: return .white
        }
    }

    private func backgroundForToPar(_ toPar: Int) -> Color {
        switch toPar {
        case ...(-2): return AppTheme.eagle
        case -1: return AppTheme.birdie
        case 0: return Color(.systemGray6)
        case 1: return AppTheme.bogey
        default: return AppTheme.double
        }
    }

    // MARK: - Trend Card

    private var trendCard: some View {
        let recent = Array(completedRounds.prefix(10).reversed())
        guard recent.count >= 2 else { return AnyView(EmptyView()) }

        let scores = recent.map(\.totalScore)
        let minScore = (scores.min() ?? 70) - 2
        let maxScore = (scores.max() ?? 100) + 2
        let range = Double(max(maxScore - minScore, 1))

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Scoring trend")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Last \(recent.count) rounds")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                GeometryReader { geo in
                    let w = geo.size.width
                    let h: CGFloat = 60
                    let stepX = w / CGFloat(scores.count - 1)

                    let points = scores.enumerated().map { i, s in
                        CGPoint(x: stepX * CGFloat(i),
                                y: h - (CGFloat(s - minScore) / CGFloat(range)) * h)
                    }

                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: points[0].x, y: h))
                            path.addLine(to: points[0])
                            for pt in points.dropFirst() { path.addLine(to: pt) }
                            path.addLine(to: CGPoint(x: points.last!.x, y: h))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(colors: [AppTheme.fairwayGreen.opacity(0.15), AppTheme.fairwayGreen.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom)
                        )

                        Path { path in
                            path.move(to: points[0])
                            for pt in points.dropFirst() { path.addLine(to: pt) }
                        }
                        .stroke(AppTheme.fairwayGreen, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        ForEach(Array(points.enumerated()), id: \.offset) { i, pt in
                            Circle()
                                .fill(AppTheme.fairwayGreen)
                                .frame(width: 6, height: 6)
                                .position(pt)
                        }

                        if let lastPt = points.last, let lastScore = scores.last {
                            Text("\(lastScore)")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundStyle(AppTheme.fairwayGreen)
                                .position(x: lastPt.x, y: lastPt.y - 12)
                        }
                    }
                    .frame(height: h)
                }
                .frame(height: 60)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    // MARK: - Completed

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("History")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 4)
            .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(Array(completedRounds.enumerated()), id: \.element.id) { i, round in
                    NavigationLink {
                        RoundDetailView(round: round)
                    } label: {
                        RoundRowView(round: round)
                    }
                    .buttonStyle(.plain)

                    if i < completedRounds.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Actions

    private func handlePlusTap() {
        if let existing = incompleteRounds.first {
            openRound(existing)
        } else {
            selectedCourse = courses.first
            showTeeSelector = true
        }
    }

    private func openRound(_ round: Round) {
        activeRound = round
        showActiveRound = true
    }

    private func createRound(course: Course, teeName: String) {
        let round = Round(date: .now, isComplete: false, tee: teeName, course: course)
        modelContext.insert(round)
        for hole in course.sortedHoles {
            let hs = HoleScore(
                holeNumber: hole.holeNumber,
                score: hole.par,
                putts: 2,
                holePar: hole.par,
                holeName: hole.name,
                holeYardage: hole.yardage(for: teeName),
                holeMensHdcp: hole.mensHdcp
            )
            hs.round = round
            modelContext.insert(hs)
        }
        try? modelContext.save()
        Haptics.success()
        openRound(round)
    }
}

// MARK: - Tee Selection

struct TeeSelectionView: View {
    let course: Course
    var onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ForEach(course.teeInfos.sorted(by: { $0.sortOrder < $1.sortOrder })) { tee in
                    Button {
                        Haptics.medium()
                        onSelect(tee.name)
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(tee.color)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(color: tee.color.opacity(0.3), radius: 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tee.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(course.totalYardage(for: tee.name)) yds · \(tee.rating)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Select tees")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Round Row

struct RoundRowView: View {
    let round: Round

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("\(round.totalScore)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                Text(round.scoreToParString)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.scoreColor(round.scoreToPar))
            }
            .frame(width: 50)

            VStack(alignment: .leading, spacing: 5) {
                Text(round.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    Circle().fill(round.displayTeeColor).frame(width: 7, height: 7)
                    Text("\(round.teeRaw) · \(round.courseName)\(round.holesPlayed < 18 ? " · \(round.holesPlayed)h" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    ForEach(round.sortedScores, id: \.holeNumber) { score in
                        let toPar = score.scoreToPar
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(dotColor(toPar))
                            .frame(width: 4, height: toPar <= -1 ? 10 : (toPar == 0 ? 6 : min(CGFloat(toPar) * 4 + 6, 14)))
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 14, alignment: .bottom)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.0f%%", round.fairwayPct))
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        Text("FWY")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(round.totalPutts)")
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        Text("PUTTS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func dotColor(_ toPar: Int) -> Color {
        switch toPar {
        case ...(-2): return AppTheme.eagle
        case -1: return AppTheme.birdie
        case 0: return Color(.systemGray4)
        case 1: return AppTheme.bogey
        default: return AppTheme.double
        }
    }
}
