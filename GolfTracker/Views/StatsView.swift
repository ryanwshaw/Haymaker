import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \Course.createdAt) private var courses: [Course]
    @State private var selectedCourse: Course? = nil
    @State private var selectedTee: String? = nil

    private var completedRounds: [Round] {
        let completed = allRounds.filter(\.isComplete)
        if let course = selectedCourse {
            return completed.filter { $0.course?.persistentModelID == course.persistentModelID }
        }
        return completed
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
                            Color.clear.frame(height: 16)
                        }
                    }
                    .padding()
                    .animation(.spring(response: 0.35), value: selectedTee)
                    .animation(.spring(response: 0.35), value: selectedCourse?.persistentModelID)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            ZStack {
                Circle()
                    .fill(AppTheme.goldLight)
                    .frame(width: 100, height: 100)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.gold)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            }
            VStack(spacing: 8) {
                Text("No stats yet")
                    .font(.title3.bold())
                Text("Play a few rounds to unlock insights about your game. Stats, trends, and comparisons will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
        VStack(spacing: 14) {
            HStack {
                Text("Overview")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(engine.roundCount) rounds")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
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
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
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

    // MARK: - Scoring Breakdown

    private var scoringBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scoring")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 0) {
                scoreCategory(count: engine.eagleCount, label: "Eagle", color: AppTheme.eagle)
                scoreCategory(count: engine.birdieCount, label: "Birdie", color: AppTheme.birdie)
                scoreCategory(count: engine.parCount, label: "Par", color: Color(.systemGray3))
                scoreCategory(count: engine.bogeyCount, label: "Bogey", color: AppTheme.bogey)
                scoreCategory(count: engine.doublePlusCount, label: "Dbl+", color: AppTheme.double)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    private func scoreCategory(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f%%", engine.scorePct(count)))
                .font(.system(size: 9, weight: .bold).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
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
            Text("Approach by distance")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
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
}
