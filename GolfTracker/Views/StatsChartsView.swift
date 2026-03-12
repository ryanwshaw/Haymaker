import SwiftUI
import Charts

// MARK: - Scoring Trend Line

struct ScoringTrendChart: View {
    let rounds: [Round]

    private var recentRounds: [Round] {
        Array(rounds.prefix(15).reversed())
    }

    var body: some View {
        if recentRounds.count < 2 { return AnyView(EmptyView()) }
        let totalPar = recentRounds.first.map { $0.sortedScores.map(\.par).reduce(0, +) } ?? 72

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Scoring Trend")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Last \(recentRounds.count) rounds")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 4)

                Chart {
                    RuleMark(y: .value("Par", totalPar))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.gray.opacity(0.4))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("Par")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }

                    ForEach(Array(recentRounds.enumerated()), id: \.offset) { i, round in
                        LineMark(
                            x: .value("Round", i),
                            y: .value("Score", round.totalScore)
                        )
                        .foregroundStyle(AppTheme.fairwayGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Round", i),
                            y: .value("Score", round.totalScore)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.fairwayGreen.opacity(0.2), AppTheme.fairwayGreen.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Round", i),
                            y: .value("Score", round.totalScore)
                        )
                        .foregroundStyle(AppTheme.fairwayGreen)
                        .symbolSize(20)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(.gray.opacity(0.2))
                        AxisValueLabel()
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 140)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

// MARK: - Score Distribution Donut

struct ScoreDistributionChart: View {
    let engine: StatsEngine

    private var slices: [(label: String, count: Int, color: Color)] {
        [
            ("Eagle", engine.eagleCount, AppTheme.eagle),
            ("Birdie", engine.birdieCount, AppTheme.birdie),
            ("Par", engine.parCount, Color(.systemGray3)),
            ("Bogey", engine.bogeyCount, AppTheme.bogey),
            ("Dbl+", engine.doublePlusCount, AppTheme.double),
        ].filter { $0.count > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Score Distribution")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 16) {
                Chart(slices, id: \.label) { slice in
                    SectorMark(
                        angle: .value("Count", slice.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(3)
                }
                .frame(width: 120, height: 120)
                .overlay {
                    VStack(spacing: 0) {
                        Text("\(engine.totalHolesPlayed)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        Text("holes")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(slices, id: \.label) { slice in
                        HStack(spacing: 6) {
                            Circle().fill(slice.color).frame(width: 8, height: 8)
                            Text(slice.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(slice.count)")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                            Text(String(format: "%.0f%%", engine.scorePct(slice.count)))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Putts Per Round Trend

struct PuttsTrendChart: View {
    let rounds: [Round]

    private var recentRounds: [Round] {
        Array(rounds.prefix(15).reversed())
    }

    var body: some View {
        if recentRounds.count < 2 { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("Putts per Round")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                Chart {
                    ForEach(Array(recentRounds.enumerated()), id: \.offset) { i, round in
                        BarMark(
                            x: .value("Round", i),
                            y: .value("Putts", round.totalPutts)
                        )
                        .foregroundStyle(
                            round.totalPutts <= 30
                                ? AppTheme.fairwayGreen.opacity(0.7)
                                : (round.totalPutts <= 34
                                   ? AppTheme.bogey.opacity(0.7)
                                   : AppTheme.double.opacity(0.7))
                        )
                        .cornerRadius(3)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(.gray.opacity(0.2))
                        AxisValueLabel()
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 100)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

// MARK: - Per-Hole Avg vs Par Chart

struct HoleAvgChart: View {
    let holeStats: [HoleStat]

    var body: some View {
        if holeStats.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("Avg Score vs Par")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                Chart {
                    RuleMark(y: .value("Par", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(.gray.opacity(0.3))

                    ForEach(holeStats.filter { $0.count > 0 }, id: \.holeNumber) { stat in
                        BarMark(
                            x: .value("Hole", stat.holeNumber),
                            y: .value("Diff", stat.avgScoreToPar)
                        )
                        .foregroundStyle(AppTheme.heatMapColor(stat.avgScoreToPar))
                        .cornerRadius(3)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 9)) { value in
                        AxisValueLabel()
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(.gray.opacity(0.2))
                        AxisValueLabel()
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 120)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}
