import SwiftUI
import SwiftData

struct HoleDetailView: View {
    let holeNumber: Int
    let selectedTee: String?
    let course: Course?

    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]

    private var completedRounds: [Round] {
        allRounds.filter { $0.isComplete && $0.course?.persistentModelID == course?.persistentModelID }
    }

    private var stat: HoleStat {
        StatsEngine.filtered(rounds: completedRounds, tee: selectedTee).holeStat(holeNumber)
    }

    private var info: HoleInfo {
        course?.hole(holeNumber)?.toHoleInfo() ?? Haymaker.hole(holeNumber)
    }

    private var displayTee: String { selectedTee ?? "Gold" }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                holeHeader
                if stat.count == 0 {
                    emptyState
                } else {
                    scoringCard
                    scoreDistributionBar
                    if info.par != 3 {
                        offTheTeeCard
                    } else {
                        teeToGreenPar3Card
                    }
                    if stat.byTeeClub.count > 0 {
                        byTeeClubCard
                    }
                    if stat.byTeeColor.count > 1 {
                        byTeeColorCard
                    }
                    if info.par != 3 {
                        approachCard
                    }
                    puttingCard
                    troubleCard
                }
                Color.clear.frame(height: 16)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Hole \(holeNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var holeHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(holeNumber)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.fairwayGreen)
                    Text(info.name.isEmpty ? "Hole \(holeNumber)" : info.name)
                        .font(.title3.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Par \(info.par)")
                        .font(.headline)
                    Text("\(info.yardage(for: displayTee)) yds")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if info.mensHdcp > 0 {
                        Text("Hdcp \(info.mensHdcp)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title)
                .foregroundStyle(AppTheme.gold.opacity(0.4))
            Text("No data for this hole yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Scoring Card

    private var scoringCard: some View {
        card(title: "Scoring") {
            HStack(spacing: 0) {
                bigStat(value: String(format: "%.1f", stat.avgScore), label: "AVG")
                Divider().frame(height: 36)
                bigStat(value: "\(stat.bestScore)", label: "BEST")
                Divider().frame(height: 36)
                bigStat(value: "\(stat.worstScore)", label: "WORST")
                Divider().frame(height: 36)
                bigStat(value: "\(stat.count)", label: "PLAYED")
            }
        }
    }

    // MARK: - Score Distribution Bar

    private var scoreDistributionBar: some View {
        let items: [(String, Int, Color)] = [
            ("Eagle", stat.eagleCount, AppTheme.eagle),
            ("Birdie", stat.birdieCount, AppTheme.birdie),
            ("Par", stat.parCountVal, Color(.systemGray3)),
            ("Bogey", stat.bogeyCount, AppTheme.bogey),
            ("Dbl+", stat.doublePlusCount, AppTheme.double),
        ]
        let total = max(stat.count, 1)

        return card(title: "Score Distribution") {
            VStack(spacing: 10) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(items, id: \.0) { label, count, color in
                            if count > 0 {
                                let width = max(CGFloat(count) / CGFloat(total) * geo.size.width - 2, 4)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color)
                                    .frame(width: width, height: 20)
                            }
                        }
                    }
                }
                .frame(height: 20)

                HStack(spacing: 0) {
                    ForEach(items, id: \.0) { label, count, color in
                        VStack(spacing: 2) {
                            Text("\(count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(color)
                            Text(label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Off the Tee (Par 4/5)

    private var offTheTeeCard: some View {
        let results: [(String, String)] = [
            ("Fairway", "fairway"), ("Rough L", "rough_left"), ("Rough R", "rough_right"),
            ("Native", "native"), ("Bunker", "bunker"), ("Drop", "drop"),
        ]

        return card(title: "Off the tee") {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    bigStat(value: String(format: "%.0f%%", stat.fairwayPct), label: "FWY HIT")
                }

                VStack(spacing: 4) {
                    ForEach(results, id: \.1) { label, raw in
                        let pct = stat.teeResultPct(raw)
                        if pct > 0 {
                            resultRow(label: label, pct: pct)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tee to Green for Par 3

    private var teeToGreenPar3Card: some View {
        let results: [(String, String)] = [
            ("Green", "green"), ("Short", "short"), ("Long", "long"),
            ("Left", "left"), ("Right", "right"), ("Bunker", "bunker"),
        ]

        return card(title: "Tee shot") {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    bigStat(value: String(format: "%.0f%%", stat.girPct), label: "GREEN HIT")
                }

                VStack(spacing: 4) {
                    ForEach(results, id: \.1) { label, raw in
                        let pct = stat.teeResultPct(raw)
                        if pct > 0 {
                            resultRow(label: label, pct: pct)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Approach (Par 4/5)

    private var approachCard: some View {
        let results: [(String, String)] = [
            ("Green", "green"), ("Short", "short"), ("Long", "long"),
            ("Left", "left"), ("Right", "right"), ("Bunker", "bunker"),
        ]

        return card(title: "Approach") {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    bigStat(value: String(format: "%.0f%%", stat.girPct), label: "GIR")
                    Divider().frame(height: 36)
                    bigStat(value: String(format: "%.0f", stat.avgApproachDistance), label: "AVG DIST")
                }

                VStack(spacing: 4) {
                    ForEach(results, id: \.1) { label, raw in
                        let pct = stat.approachResultPct(raw)
                        if pct > 0 {
                            resultRow(label: label, pct: pct)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Putting

    private var puttingCard: some View {
        card(title: "Putting") {
            HStack(spacing: 0) {
                bigStat(value: String(format: "%.1f", stat.avgPutts), label: "AVG PUTTS")
                Divider().frame(height: 36)
                bigStat(value: String(format: "%.0f ft", stat.avgFirstPuttDist), label: "AVG 1st PUTT")
            }
        }
    }

    // MARK: - Trouble

    private var troubleCard: some View {
        card(title: "Trouble") {
            HStack(spacing: 0) {
                bigStat(value: "\(stat.dropCount)", label: "DROPS")
                Divider().frame(height: 36)
                bigStat(value: "\(stat.bunkerCount)", label: "BUNKERS")
                Divider().frame(height: 36)
                bigStat(value: "\(stat.nativeCount)", label: "NATIVE")
            }
        }
    }

    // MARK: - By Tee Club

    private var byTeeClubCard: some View {
        card(title: "Off the Tee by Club") {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("Club")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Times")
                        .frame(width: 44, alignment: .center)
                    Text(info.par == 3 ? "GIR%" : "Fwy%")
                        .frame(width: 48, alignment: .center)
                    Text("Avg")
                        .frame(width: 48, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

                ForEach(Array(stat.byTeeClub.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { Divider().padding(.vertical, 6) }

                    HStack(spacing: 0) {
                        // Club name + usage bar
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.clubDisplayName)
                                .font(.system(size: 13, weight: .semibold))
                            let maxCount = stat.byTeeClub.first?.count ?? 1
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.fairwayGreen.opacity(0.15))
                                    .frame(width: geo.size.width)
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(AppTheme.fairwayGreen.opacity(0.5))
                                            .frame(width: max(geo.size.width * CGFloat(item.count) / CGFloat(maxCount), 4))
                                    }
                            }
                            .frame(height: 5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(item.count)")
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .center)

                        // Fwy% or GIR%
                        let pct = info.par == 3 ? item.girPct : item.fairwayPct
                        if pct < 0 {
                            Text("—")
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .center)
                        } else {
                            Text(String(format: "%.0f%%", pct))
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(pct >= 50 ? AppTheme.fairwayGreen : AppTheme.bogey)
                                .frame(width: 48, alignment: .center)
                        }

                        // Avg score to par
                        let diff = item.avgScoreToPar
                        Text(diff == 0 ? "E" : String(format: "%+.1f", diff))
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(AppTheme.scoreColor(Int(diff.rounded())))
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - By Tee Color

    private var byTeeColorCard: some View {
        card(title: "Scoring by Tee") {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("Tee")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rounds")
                        .frame(width: 56, alignment: .center)
                    Text("Avg Score")
                        .frame(width: 72, alignment: .center)
                    Text("vs Par")
                        .frame(width: 52, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

                ForEach(Array(stat.byTeeColor.enumerated()), id: \.element.id) { idx, item in
                    if idx > 0 { Divider().padding(.vertical, 6) }

                    HStack(spacing: 0) {
                        // Tee color dot + name
                        HStack(spacing: 8) {
                            Circle()
                                .fill(GolfTracker.teeColor(for: item.teeName, in: course))
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 0.5))
                            Text(item.teeName)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(item.count)")
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .center)

                        Text(String(format: "%.1f", item.avgScore))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .frame(width: 72, alignment: .center)

                        let diff = item.avgScoreToPar
                        Text(diff == 0 ? "E" : String(format: "%+.1f", diff))
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(AppTheme.scoreColor(Int(diff.rounded())))
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Reusable Components

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            content()
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    private func bigStat(value: String, label: String) -> some View {
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

    private func resultRow(label: String, pct: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.fairwayGreen.opacity(0.2))
                    .frame(width: geo.size.width)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.fairwayGreen)
                            .frame(width: max(geo.size.width * pct / 100, 4))
                    }
            }
            .frame(height: 14)
            Text(String(format: "%.0f%%", pct))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
