import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \Course.createdAt) private var courses: [Course]
    @State private var selectedCourse: Course? = nil
    @State private var selectedTee: String? = nil
    @State private var selectedDrinkFilter: String? = nil

    private var completedRounds: [Round] {
        var rounds = allRounds.filter(\.isComplete)
        if let course = selectedCourse {
            rounds = rounds.filter { $0.course?.persistentModelID == course.persistentModelID }
        }
        if let bucket = selectedDrinkFilter {
            if bucket == "Boozing" {
                rounds = rounds.filter { $0.isBoozing || $0.totalDrinks > 0 }
            } else {
                rounds = rounds.filter { $0.drinkBucket == bucket }
            }
        }
        return rounds
    }

    private var hasBoozeData: Bool {
        allRounds.filter(\.isComplete).contains(where: { $0.isBoozing || $0.totalDrinks > 0 })
    }

    private var engine: StatsEngine { StatsEngine.filtered(rounds: completedRounds, tee: selectedTee) }

    private var availableTees: [CourseTeeInfo] {
        selectedCourse?.teeInfos.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
    }

    private var isSingleCourse: Bool { selectedCourse != nil }

    var body: some View {
        Group {
            if allRounds.filter(\.isComplete).isEmpty {
                ScrollView {
                    emptyState
                }
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        courseFilter
                        if isSingleCourse {
                            teeFilter
                        }
                        if hasBoozeData {
                            drinkFilter
                        }
                        if engine.roundCount == 0 {
                            noDataForTee
                        } else {
                            overviewCard.staggeredAppear(index: 0)
                            ScoringTrendChart(rounds: engine.rounds).staggeredAppear(index: 1)
                            ScoreDistributionChart(engine: engine).staggeredAppear(index: 2)
                            PuttsTrendChart(rounds: engine.rounds).staggeredAppear(index: 3)
                            if isSingleCourse {
                                HoleAvgChart(holeStats: engine.holeStats).staggeredAppear(index: 4)
                                heatMapSection.staggeredAppear(index: 5)
                            }
                            approachByDistanceCard.staggeredAppear(index: isSingleCourse ? 6 : 4)
                            if hasBoozeData {
                                boozeAnalysisCard.staggeredAppear(index: isSingleCourse ? 7 : 5)
                            }
                            Color.clear.frame(height: 16)
                        }
                    }
                    .padding()
                    .animation(.spring(response: 0.35), value: selectedTee)
                    .animation(.spring(response: 0.35), value: selectedCourse?.persistentModelID)
                    .animation(.spring(response: 0.35), value: selectedDrinkFilter)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(AppTheme.fairwayGreen.opacity(0.08))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(AppTheme.fairwayGreen.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.fairwayGreen)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            }

            VStack(spacing: 8) {
                Text("Your Stats Dashboard")
                    .font(.title3.bold())
                Text("Log rounds to unlock deep insights into your game. Here's what you'll see:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                statsPreviewRow(icon: "number", title: "Scoring Overview", detail: "Avg score, front/back 9, best round, FWY%, GIR%")
                statsPreviewRow(icon: "chart.xyaxis.line", title: "Scoring Trend", detail: "Round-over-round chart showing your progress")
                statsPreviewRow(icon: "circle.grid.3x3", title: "Hole-by-Hole Heatmap", detail: "Color-coded avg to par on every hole of your course")
                statsPreviewRow(icon: "scope", title: "Approach by Distance", detail: "GIR% in 10-yard buckets — find your sweet spot")
                statsPreviewRow(icon: "flag.fill", title: "Tee Club Breakdown", detail: "Scoring avg and fairway % by club on each hole")
                statsPreviewRow(icon: "wineglass.fill", title: "Booze Report", detail: "Compare your sober vs. boozy scoring averages")
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func statsPreviewRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.mauve)
                .frame(width: 32, height: 32)
                .background(AppTheme.mauve.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var noDataForTee: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No rounds from \(selectedTee ?? "") tees")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Course Filter

    private var courseFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                courseChip(label: "All Courses", course: nil)
                ForEach(courses) { course in
                    courseChip(label: course.name, course: course)
                }
            }
        }
    }

    private func courseChip(label: String, course: Course?) -> some View {
        let isActive = selectedCourse?.persistentModelID == course?.persistentModelID
        return Button {
            Haptics.selection()
            selectedCourse = course
            selectedTee = nil
        } label: {
            HStack(spacing: 5) {
                if course != nil {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 8))
                }
                Text(label)
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? AppTheme.darkGreen : AppTheme.subtleBackground, in: Capsule())
            .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tee Filter

    private var teeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                teeChip(label: "All tees", teeName: nil)
                ForEach(availableTees) { tee in
                    teeChip(label: tee.name, teeName: tee.name, dotColor: tee.color)
                }
            }
        }
    }

    private func teeChip(label: String, teeName: String?, dotColor: Color? = nil) -> some View {
        let isActive = selectedTee == teeName
        return Button {
            Haptics.selection()
            selectedTee = teeName
        } label: {
            HStack(spacing: 5) {
                if let dot = dotColor {
                    Circle().fill(dot).frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? AppTheme.fairwayGreen : AppTheme.subtleBackground, in: Capsule())
            .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Overview")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                Spacer()
                Text("\(engine.roundCount) rounds")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.deepGreenGradient)

            VStack(spacing: 14) {
                scoringAveragesRow
                HStack(spacing: 0) {
                    overviewStat(value: String(format: "%.1f", engine.avgPutts), label: "PUTTS/RND")
                    statDivider
                    overviewStat(value: String(format: "%.0f%%", engine.fairwayPct), label: "FWY")
                    statDivider
                    overviewStat(value: String(format: "%.0f%%", engine.girPct), label: "GIR")
                }
                HStack(spacing: 0) {
                    overviewStat(value: String(format: "%.1f", engine.dropsPerRound), label: "DROPS/RND")
                    statDivider
                    overviewStat(value: String(format: "%.0f", engine.avgApproachDistance), label: "AVG APPR")
                    statDivider
                    overviewStat(value: String(format: "%.0f%%", engine.scramblePct), label: "SCRAMBLE")
                }
                .padding(.top, 4)

                if !engine.chipAttemptBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SHORT GAME ATTEMPTS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(engine.chipAttemptBreakdown) { stat in
                                VStack(spacing: 2) {
                                    Text(String(format: "%.0f%%", stat.pct))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(stat.attempts == 1 ? AppTheme.fairwayGreen : stat.attempts >= 3 ? AppTheme.double : .orange)
                                    Text(stat.attempts == 1 ? "1 chip" : "\(stat.attempts)x chips")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(16)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var scoringAveragesRow: some View {
        HStack(spacing: 0) {
            scoringAvgStat(value: engine.avg18HoleScore, label: "18-HOLE")
            statDivider
            scoringAvgStat(value: engine.avgFront9Score, label: "FRONT 9")
            statDivider
            scoringAvgStat(value: engine.avgBack9Score, label: "BACK 9")
            if let best = engine.best18HoleScore {
                statDivider
                overviewStat(value: "\(best)", label: "BEST 18")
            }
        }
    }

    private func scoringAvgStat(value: Double?, label: String) -> some View {
        VStack(spacing: 3) {
            if let v = value {
                Text(String(format: "%.1f", v))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppTheme.fairwayGreen)
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(.tertiary)
            }
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func overviewStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.fairwayGreen)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Divider().frame(height: 32)
    }

    // MARK: - Heat Map

    private var heatMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hole-by-hole")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            let stats = engine.holeStats
            let stdDev = engine.heatMapOutlierThreshold
            let meanDiff = stats.filter { $0.count > 0 }.map(\.avgScoreToPar).reduce(0, +)
                / max(Double(stats.filter { $0.count > 0 }.count), 1)

            let half = stats.count / 2

            VStack(spacing: 4) {
                if half > 0 {
                    heatMapLabel("FRONT \(half)")
                    heatMapRow(stats: Array(stats.prefix(half)), stdDev: stdDev, meanDiff: meanDiff)
                    heatMapLabel("BACK \(stats.count - half)")
                    heatMapRow(stats: Array(stats.suffix(stats.count - half)), stdDev: stdDev, meanDiff: meanDiff)
                }
            }
            .padding(12)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    private func heatMapLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
    }

    private func heatMapRow(stats: [HoleStat], stdDev: Double, meanDiff: Double) -> some View {
        let columnCount = max(stats.count, 1)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount), spacing: 4) {
            ForEach(stats, id: \.holeNumber) { stat in
                let isOutlier = stat.count > 0 && abs(stat.avgScoreToPar - meanDiff) > stdDev
                NavigationLink {
                    HoleDetailView(holeNumber: stat.holeNumber, selectedTee: selectedTee, course: selectedCourse)
                } label: {
                    VStack(spacing: 2) {
                        Text("\(stat.holeNumber)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        if stat.count > 0 {
                            Text(String(format: "%.1f", stat.avgScore))
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        } else {
                            Text("—")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        stat.count > 0
                            ? AppTheme.heatMapColor(stat.avgScoreToPar)
                            : AppTheme.subtleBackground,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(
                        isOutlier
                            ? RoundedRectangle(cornerRadius: 8).stroke(AppTheme.gold, lineWidth: 2)
                            : nil
                    )
                    .foregroundStyle(stat.count > 0 ? .white : .secondary)
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Approach by Distance

    private var approachByDistanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.mauve)
                Text("Approach by distance")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)

            let items = engine.approachByDistance
            if items.isEmpty {
                HStack {
                    Spacer()
                    Text("No approach data yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(20)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                        NavigationLink {
                            ApproachDistanceDetailView(stat: item)
                        } label: {
                            approachRow(item: item)
                        }
                        .buttonStyle(.plain)

                        if i < items.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    private func approachRow(item: ApproachDistanceStat) -> some View {
        HStack(spacing: 10) {
            Text(item.label)
                .font(.subheadline.bold())
                .frame(width: 64, alignment: .leading)
            Text("\(item.count)x")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
            Spacer()
            Text(String(format: "%.0f%%", item.greenPct))
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(item.greenPct > 50 ? AppTheme.fairwayGreen : (item.greenPct > 25 ? AppTheme.bogey : AppTheme.double))
            Text("GIR")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Drink Filter

    private var drinkFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                drinkChip(label: "All rounds", icon: nil, bucket: nil)
                drinkChip(label: "Sober", icon: nil, bucket: "Sober")
                drinkChip(label: "Boozing", icon: "wineglass.fill", bucket: "Boozing")
                ForEach(["1-5", "6-10", "11-15", "15+"], id: \.self) { bucket in
                    drinkChip(label: "\(bucket) drinks", icon: "wineglass.fill", bucket: bucket)
                }
            }
        }
    }

    private func drinkChip(label: String, icon: String?, bucket: String?) -> some View {
        let isActive = selectedDrinkFilter == bucket
        let isBoozy = bucket != nil && bucket != "Sober"
        return Button {
            Haptics.selection()
            selectedDrinkFilter = (selectedDrinkFilter == bucket) ? nil : bucket
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isActive ? (isBoozy ? AppTheme.gold : AppTheme.fairwayGreen) : AppTheme.subtleBackground,
                in: Capsule()
            )
            .foregroundStyle(isActive ? (isBoozy ? AppTheme.darkGreen : .white) : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Booze Analysis Card

    private var boozeAnalysisCard: some View {
        let allCompleted = allRounds.filter(\.isComplete)
        let boozingRounds = allCompleted.filter { $0.isBoozing || $0.totalDrinks > 0 }
        let soberRounds = allCompleted.filter { !$0.isBoozing && $0.totalDrinks == 0 }
        let progressEngine = StatsEngine(rounds: boozingRounds)
        let progressData = progressEngine.scoreByDrinkProgress

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wineglass.fill")
                    .foregroundStyle(AppTheme.gold)
                Text("Booze Report")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(boozingRounds.count) boozy / \(soberRounds.count) sober")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 4)

            // Sober vs Boozing comparison
            VStack(spacing: 0) {
                boozeCompareRow(label: "Avg Score",
                    boozingVal: avgScore(boozingRounds),
                    soberVal: avgScore(soberRounds))
                Divider().padding(.leading, 14)
                boozeCompareRow(label: "Avg Putts",
                    boozingVal: avgPuttsVal(boozingRounds),
                    soberVal: avgPuttsVal(soberRounds))
                Divider().padding(.leading, 14)
                boozeCompareRow(label: "FWY %",
                    boozingVal: avgFairway(boozingRounds),
                    soberVal: avgFairway(soberRounds))
                Divider().padding(.leading, 14)
                boozeCompareRow(label: "GIR %",
                    boozingVal: avgGir(boozingRounds),
                    soberVal: avgGir(soberRounds))
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

            // Score as drinks flow through the round
            if !progressData.isEmpty {
                drinkProgressCard(data: progressData)
            }
        }
    }

    private func drinkProgressCard(data: [StatsEngine.DrinkProgressStat]) -> some View {
        let worstAvg = data.map(\.avgScoreToPar).max() ?? 1
        let bestAvg = data.map(\.avgScoreToPar).min() ?? 0
        let range = max(worstAvg - bestAvg, 0.5)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.gold)
                Text("Score as drinks flow")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("avg vs par per hole")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            VStack(spacing: 6) {
                ForEach(data) { point in
                    HStack(spacing: 10) {
                        // Label
                        HStack(spacing: 4) {
                            if point.minDrinks > 0 {
                                Image(systemName: "wineglass.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.gold.opacity(min(0.4 + Double(point.minDrinks) * 0.12, 1.0)))
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            Text(point.label)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(width: 72, alignment: .leading)

                        // Bar
                        GeometryReader { geo in
                            let normalised = (point.avgScoreToPar - bestAvg) / range
                            let barWidth = max(geo.size.width * CGFloat(normalised), 6)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppTheme.subtleBackground)
                                    .frame(width: geo.size.width, height: 14)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(scoreProgressColor(point.avgScoreToPar))
                                    .frame(width: barWidth, height: 14)
                            }
                        }
                        .frame(height: 14)

                        // Value
                        let diff = point.avgScoreToPar
                        Text(diff == 0 ? "E" : String(format: "%+.1f", diff))
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(scoreProgressColor(diff))
                            .frame(width: 36, alignment: .trailing)

                        // Sample count
                        Text("\(point.count)")
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                            .frame(width: 20, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func scoreProgressColor(_ avgScoreToPar: Double) -> Color {
        if avgScoreToPar <= -0.5 { return AppTheme.birdie }
        if avgScoreToPar <= 0.2  { return AppTheme.fairwayGreen }
        if avgScoreToPar <= 0.7  { return AppTheme.bogey }
        return AppTheme.double
    }

    private func boozeCompareRow(label: String, boozingVal: Double?, soberVal: Double?) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.bold())
                .frame(width: 80, alignment: .leading)
            Spacer()
            VStack(spacing: 1) {
                if let v = boozingVal {
                    Text(String(format: label.contains("%") ? "%.0f%%" : "%.1f", v))
                        .font(.subheadline.bold().monospacedDigit())
                } else {
                    Text("—").font(.subheadline).foregroundStyle(.tertiary)
                }
                Text("BOOZY")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(AppTheme.gold)
            }
            .frame(width: 60)
            VStack(spacing: 1) {
                if let v = soberVal {
                    Text(String(format: label.contains("%") ? "%.0f%%" : "%.1f", v))
                        .font(.subheadline.bold().monospacedDigit())
                } else {
                    Text("—").font(.subheadline).foregroundStyle(.tertiary)
                }
                Text("SOBER")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(AppTheme.fairwayGreen)
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func avgScore(_ rounds: [Round]) -> Double? {
        let full = rounds.filter(\.hasFull18)
        guard !full.isEmpty else { return nil }
        return Double(full.map(\.totalScore).reduce(0, +)) / Double(full.count)
    }

    private func avgPuttsVal(_ rounds: [Round]) -> Double? {
        guard !rounds.isEmpty else { return nil }
        return Double(rounds.map(\.totalPutts).reduce(0, +)) / Double(rounds.count)
    }

    private func avgFairway(_ rounds: [Round]) -> Double? {
        guard !rounds.isEmpty else { return nil }
        let total = rounds.map(\.fairwayPct).reduce(0, +)
        return total / Double(rounds.count)
    }

    private func avgGir(_ rounds: [Round]) -> Double? {
        guard !rounds.isEmpty else { return nil }
        let total = rounds.map(\.girPct).reduce(0, +)
        return total / Double(rounds.count)
    }
}
