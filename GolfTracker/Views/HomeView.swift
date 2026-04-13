import SwiftUI
import SwiftData

private struct RoundPresentation: Identifiable {
    let id = UUID()
    let round: Round
    let match: Match?
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \Course.createdAt) private var courses: [Course]
    @Query(filter: #Predicate<Match> { !$0.isComplete }) private var activeMatches: [Match]

    @State private var activeRound: Round?
    @State private var roundPresentation: RoundPresentation?
    @State private var showCoursePicker = false
    @State private var showTeeSelector = false
    @State private var showBoozingPrompt = false
    @State private var showScorecardScanner = false
    @State private var selectedCourse: Course?
    @State private var selectedTee: String?
    @State private var pendingBoozing: Bool?
    @State private var showRoundExistsAlert = false
    @State private var showMatchSetup = false
    @State private var activeMatch: Match?
    @State private var showMatchResults = false
    @State private var completedMatch: Match?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("boozingPromptEnabled") private var boozingPromptEnabled = true
    @AppStorage("hasDemoData") private var hasDemoData = false
    @ObservedObject private var bag = BagManager.shared

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }
    private var incompleteRounds: [Round] { allRounds.filter { !$0.isComplete } }
    private var bagIsEmpty: Bool { bag.clubs.isEmpty || bag.clubYardages.isEmpty }

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
                // createMatchButton.staggeredAppear(index: 2)  // Temporarily hidden

                if bagIsEmpty && hasSeenOnboarding {
                    bagSetupBanner.staggeredAppear(index: 3)
                }

                if !completedRounds.isEmpty {
                    lastRoundCard.staggeredAppear(index: 4)
                    BirdieTrackerCard().staggeredAppear(index: 5)
                    trendCard.staggeredAppear(index: 6)
                    completedSection.staggeredAppear(index: 7)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(item: $roundPresentation) { presentation in
            ActiveRoundView(
                round: presentation.round,
                match: presentation.match,
                onMatchFinished: { finishedMatch in
                    roundPresentation = nil
                    activeRound = nil
                    completedMatch = finishedMatch
                    activeMatch = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showMatchResults = true
                    }
                },
                onDismiss: {
                    roundPresentation = nil
                    activeRound = nil
                }
            )
        }
        .sheet(isPresented: $showCoursePicker) {
            CoursePickerView(courses: courses, allRounds: allRounds) { course in
                showCoursePicker = false
                selectedCourse = course
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTeeSelector = true
                }
            }
            .presentationDetents([.large])
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showTeeSelector) {
            if let course = selectedCourse {
                TeeSelectionView(course: course) { teeName in
                    selectedTee = teeName
                    showTeeSelector = false
                }
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
            }
        }
        .onChange(of: showTeeSelector) { _, showing in
            guard !showing, let course = selectedCourse, let tee = selectedTee else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if boozingPromptEnabled {
                    showBoozingPrompt = true
                } else {
                    createRound(course: course, teeName: tee, isBoozing: false)
                }
            }
        }
        .alert("Are you boozing today?", isPresented: $showBoozingPrompt) {
            Button("Yes") { pendingBoozing = true }
            Button("No") { pendingBoozing = false }
            Button("Don't ask again", role: .destructive) {
                boozingPromptEnabled = false
                pendingBoozing = false
            }
        } message: {
            Text("Track your drinks throughout the round for scoring insights.")
        }
        .onChange(of: showBoozingPrompt) { _, showing in
            guard !showing, let boozing = pendingBoozing,
                  let course = selectedCourse, let tee = selectedTee else { return }
            pendingBoozing = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                createRound(course: course, teeName: tee, isBoozing: boozing)
            }
        }
        .sheet(isPresented: $showMatchSetup) {
            MatchSetupView { match in
                activeMatch = match
                if let round = match.round {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        openRound(round)
                    }
                }
            }
        }
        .sheet(isPresented: $showMatchResults) {
            if let match = completedMatch {
                MatchResultsView(match: match)
            }
        }
        .confirmationDialog("Round in progress", isPresented: $showRoundExistsAlert, titleVisibility: .visible) {
            Button("Continue current round") {
                if let existing = incompleteRounds.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        openRound(existing)
                    }
                }
            }
            Button("Discard & start new round", role: .destructive) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    discardAndStartNew()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have a round in progress. Starting a new round will discard it.")
        }
        .sheet(isPresented: $showScorecardScanner) {
            ScorecardScannerView {
                showScorecardScanner = false
            }
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

            Text("Welcome to HomeCourse Hero")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 12) {
                onboardingStep(icon: "1.circle.fill", color: AppTheme.fairwayGreen,
                               title: "Track rounds", detail: "Log every shot hole-by-hole")
                onboardingStep(icon: "2.circle.fill", color: AppTheme.mauve,
                               title: "Analyze your game", detail: "Charts, trends, and per-hole stats")
                onboardingStep(icon: "3.circle.fill", color: AppTheme.gold,
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
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.mauveLight)
                    .frame(width: 72, height: 72)
                Image(systemName: "figure.golf")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.mauve)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            }
            Text("Ready to play?")
                .font(.headline)
            Text("Start your first round to begin tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Demo data loader commented out for App Store release
            // if !hasDemoData {
            //     Divider().padding(.vertical, 4)
            //     VStack(spacing: 6) {
            //         Text("Want to explore the app first?")
            //         Button { loadDemoData() } label: {
            //             Label("Load Sample Data", systemImage: "wand.and.stars")
            //         }
            //     }
            // }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                AppTheme.cardBackground
                LinearGradient(colors: [AppTheme.mauve.opacity(0.06), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var bagSetupBanner: some View {
        NavigationLink {
            BagEditorView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.gold.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set up your bag")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Add your clubs to unlock Virtual Caddie recommendations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    AppTheme.cardBackground
                    LinearGradient(colors: [AppTheme.gold.opacity(0.05), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.gold.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadDemoData() {
        MockDataGenerator.generate(in: modelContext)
        // Also seed a sample bag so caddie and stats work
        let sampleClubs: [Club] = [.driver, .threeWood, .fiveWood, .hybrid,
                                    .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron,
                                    .pitchingWedge, .gapWedge, .sandWedge, .lobWedge, .putter]
        let sampleYardages: [Club: Int] = [
            .driver: 245, .threeWood: 220, .fiveWood: 205, .hybrid: 190,
            .fiveIron: 175, .sixIron: 165, .sevenIron: 155, .eightIron: 144,
            .nineIron: 132, .pitchingWedge: 120, .gapWedge: 108,
            .sandWedge: 94, .lobWedge: 78, .putter: 0
        ]
        BagManager.shared.clubs = sampleClubs
        for (club, yds) in sampleYardages {
            BagManager.shared.clubYardages[club] = yds
        }
        hasDemoData = true
        Haptics.success()
    }

    // MARK: - In Progress Card

    private func inProgressCard(_ round: Round) -> some View {
        let matchForRound = activeMatches.first(where: { $0.round?.id == round.id })

        return Button {
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
                    HStack(spacing: 6) {
                        Text("Continue round")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let matchForRound {
                            Text(matchForRound.gameType.displayName)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.darkGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.mauve, in: Capsule())
                        }
                    }
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
                    .foregroundStyle(Color.gray.opacity(0.4))
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

    // MARK: - Create Match Button

    private var createMatchButton: some View {
        Button {
            Haptics.medium()
            showMatchSetup = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.headline)
                Text("Create a match")
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
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 10, weight: .bold))
                    Text("Last round")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(last.displayTeeColor).frame(width: 7, height: 7)
                    Text(last.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.deepGreenGradient)

            VStack(alignment: .leading, spacing: 12) {
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
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
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
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.mauve)
                        Text("Scoring trend")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
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
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.mauve)
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
        if courses.count == 1 && !GolfCourseAPIService.shared.hasAPIKey {
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
        if activeMatch == nil {
            activeMatch = activeMatches.first(where: { $0.round?.id == round.id })
        }
        activeRound = round
        roundPresentation = RoundPresentation(round: round, match: activeMatch)
    }

    private func createRound(course: Course, teeName: String, isBoozing: Bool = false) {
        guard !course.sortedHoles.isEmpty else { return }
        let round = Round(date: .now, isComplete: false, tee: teeName, isBoozing: isBoozing, course: course)
        modelContext.insert(round)
        var holeScores: [HoleScore] = []
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
            holeScores.append(hs)
        }
        round.scores = holeScores
        try? modelContext.save()
        Haptics.success()
        activeMatch = nil
        activeRound = round
        roundPresentation = RoundPresentation(round: round, match: nil)
    }
}

// MARK: - Course Picker

struct CoursePickerView: View {
    let courses: [Course]
    let allRounds: [Round]
    var onSelect: (Course) -> Void

    @State private var searchQuery = ""
    @State private var searchResults: [GCSearchResult] = []
    @State private var isSearching = false
    @State private var searchError = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isSavingCourse = false
    @Environment(\.modelContext) private var modelContext

    private var sortedCourses: [Course] {
        let counts = Dictionary(allRounds.compactMap(\.course).map { ($0.id, 1) }, uniquingKeysWith: +)
        return courses.sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for a course...", text: $searchQuery)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onSubmit { performSearch() }
                    if isSearching || isSavingCourse {
                        ProgressView().controlSize(.small)
                    } else if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                            searchError = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
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
                        .padding(.top, 6)
                }

                ScrollView {
                    VStack(spacing: 10) {
                        if searchQuery.isEmpty {
                            if !sortedCourses.isEmpty {
                                sectionHeader("RECENT COURSES")
                            }
                            ForEach(sortedCourses) { course in
                                savedCourseRow(course)
                            }
                        } else if !searchResults.isEmpty {
                            sectionHeader("SEARCH RESULTS")
                            ForEach(searchResults) { result in
                                apiCourseRow(result)
                            }
                        } else if !isSearching {
                            VStack(spacing: 8) {
                                Image(systemName: "flag.slash")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.tertiary)
                                Text("No courses found")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Course")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: searchQuery) { _, newValue in
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    searchResults = []
                    searchError = ""
                    return
                }
                debounceSearch()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func savedCourseRow(_ course: Course) -> some View {
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
                    let roundCount = allRounds.filter { $0.course?.id == course.id }.count
                    Text("\(course.sortedHoles.count) holes · Par \(course.totalPar) · \(roundCount) round\(roundCount == 1 ? "" : "s")")
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

    private func apiCourseRow(_ result: GCSearchResult) -> some View {
        Button {
            Haptics.medium()
            saveAndSelect(result)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "flag.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.fairwayGreen)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.fairwayGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if !result.locationString.isEmpty {
                        Text(result.locationString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
        .disabled(isSavingCourse)
    }

    private func saveAndSelect(_ result: GCSearchResult) {
        guard result.hasTeeData else {
            searchError = "This course doesn't have hole data available."
            return
        }
        isSavingCourse = true
        let parsed = result.toParsedCourseData()

        let tees = parsed.teeNames.enumerated().map { i, name in
            CourseTeeInfo(name: name, colorHex: teeColorHex(for: name), rating: "—", sortOrder: i)
        }

        let course = Course(name: parsed.name, tees: tees)
        modelContext.insert(course)

        for hole in parsed.holes {
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
        isSavingCourse = false
        onSelect(course)
    }

    private func teeColorHex(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("black") { return "1C1C1E" }
        if n.contains("blue") { return "007AFF" }
        if n.contains("white") { return "C7C7CC" }
        if n.contains("gold") { return "FFD60A" }
        if n.contains("red") { return "FF3B30" }
        if n.contains("silver") { return "A8A8A8" }
        if n.contains("green") { return "34C759" }
        return "8E8E93"
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { performSearch() }
        }
    }

    private func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
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
            ZStack {
                Circle()
                    .fill(AppTheme.deepGreen.opacity(0.12))
                    .frame(width: 52, height: 52)
                VStack(spacing: 2) {
                    Text("\(round.totalScore)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text(round.scoreToParString)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.scoreColor(round.scoreToPar))
                }
            }
            .frame(width: 52)

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
