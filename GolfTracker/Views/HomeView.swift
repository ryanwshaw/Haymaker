import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \Course.createdAt) private var courses: [Course]

    @State private var activeRound: Round?
    @State private var showCoursePicker = false
    @State private var showTeeSelector = false
    @State private var selectedCourse: Course?
    @State private var showRoundExistsAlert = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }
    private var incompleteRounds: [Round] { allRounds.filter { !$0.isComplete } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !hasSeenOnboarding {
                    onboardingCard.staggeredAppear(index: 0)
                }
                if completedRounds.isEmpty && hasSeenOnboarding {
                    emptyHeroCard.staggeredAppear(index: 0)
                }
                if let active = incompleteRounds.first {
                    inProgressCard(active)
                        .staggeredAppear(index: 0)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                newRoundButton.staggeredAppear(index: 1)

                if !completedRounds.isEmpty {
                    lastRoundCard.staggeredAppear(index: 2)
                    trendCard.staggeredAppear(index: 3)
                    completedSection.staggeredAppear(index: 4)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(item: $activeRound) { round in
            ActiveRoundView(round: round) { activeRound = nil }
        }
        .sheet(isPresented: $showCoursePicker) {
            CoursePickerView(courses: courses) { course in
                showCoursePicker = false
                selectedCourse = course
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTeeSelector = true
                }
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showTeeSelector) {
            if let course = selectedCourse {
                TeeSelectionView(course: course) { teeName in
                    showTeeSelector = false
                    createRound(course: course, teeName: teeName)
                }
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
            }
        }
        .confirmationDialog("Round in progress", isPresented: $showRoundExistsAlert, titleVisibility: .visible) {
            Button("Continue current round") {
                if let existing = incompleteRounds.first {
                    openRound(existing)
                }
            }
            Button("Discard & start new round", role: .destructive) {
                discardAndStartNew()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have a round in progress. Starting a new round will discard it.")
        }
    }

    // MARK: - Onboarding

    private var onboardingCard: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray5), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "figure.golf")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.fairwayGreen)

            Text("Welcome to GolfTracker")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 12) {
                onboardingStep(icon: "1.circle.fill", color: AppTheme.fairwayGreen,
                               title: "Track rounds", detail: "Log every shot hole-by-hole")
                onboardingStep(icon: "2.circle.fill", color: AppTheme.gold,
                               title: "Analyze your game", detail: "Charts, trends, and per-hole stats")
                onboardingStep(icon: "3.circle.fill", color: AppTheme.eagle,
                               title: "Compete with friends", detail: "Compare scores and see who plays better")
            }
            .padding(.horizontal, 8)

            Button {
                withAnimation(.spring(response: 0.3)) {
                    hasSeenOnboarding = true
                }
                Haptics.light()
            } label: {
                Text("Get started")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.headerGradient, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private func onboardingStep(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Empty Hero

    private var emptyHeroCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.golf")
                .font(.system(size: 38))
                .foregroundStyle(AppTheme.gold)
                .symbolEffect(.pulse.byLayer, options: .repeating)
            Text("Ready to play?")
                .font(.headline)
            Text("Start your first round to begin tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
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
        if incompleteRounds.first != nil {
            showRoundExistsAlert = true
        } else {
            startNewRoundFlow()
        }
    }

    private func startNewRoundFlow() {
        if courses.count == 1 {
            selectedCourse = courses.first
            showTeeSelector = true
        } else {
            showCoursePicker = true
        }
    }

    private func discardAndStartNew() {
        for round in incompleteRounds {
            modelContext.delete(round)
        }
        try? modelContext.save()
        startNewRoundFlow()
    }

    private func openRound(_ round: Round) {
        activeRound = round
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

// MARK: - Course Picker

struct CoursePickerView: View {
    let courses: [Course]
    var onSelect: (Course) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(courses) { course in
                        Button {
                            Haptics.medium()
                            onSelect(course)
                        } label: {
                            HStack(spacing: 14) {
                                if let logo = course.logoImage {
                                    Image(uiImage: logo)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                                } else {
                                    Image(systemName: "flag.fill")
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.fairwayGreen)
                                        .frame(width: 40, height: 40)
                                        .background(AppTheme.fairwayGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(course.sortedHoles.count) holes · Par \(course.totalPar) · \(course.teeInfos.count) tees")
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
            }
            .navigationTitle("Select course")
            .navigationBarTitleDisplayMode(.inline)
        }
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
