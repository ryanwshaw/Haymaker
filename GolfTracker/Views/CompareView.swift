import SwiftUI

struct CompareView: View {
    let friendName: String
    let friendRounds: [SharedRoundSummary]
    let myRounds: [SharedRoundSummary]

    private var myEngine: FriendStatsEngine { FriendStatsEngine(rounds: myRounds) }
    private var theirEngine: FriendStatsEngine { FriendStatsEngine(rounds: friendRounds) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headerCard
                scoringComparison
                statsComparison
                insightsCard
                holeByHoleComparison
                Color.clear.frame(height: 16)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Head to Head")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                playerAvatar("You", color: AppTheme.fairwayGreen)
                Text("You")
                    .font(.caption.bold())
                Text("\(myEngine.roundCount) rnds")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.gold)
                Text("VS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(AppTheme.gold)
            }
            .frame(width: 60)

            VStack(spacing: 4) {
                playerAvatar(friendName, color: AppTheme.eagle)
                Text(friendName)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text("\(theirEngine.roundCount) rnds")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func playerAvatar(_ name: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 48, height: 48)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    // MARK: - Scoring Comparison

    private var scoringComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scoring Averages")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                compareRow(label: "18-Hole Avg",
                           left: myEngine.avg18HoleScore.map { String(format: "%.1f", $0) },
                           right: theirEngine.avg18HoleScore.map { String(format: "%.1f", $0) },
                           lowerIsBetter: true)
                Divider().padding(.horizontal, 14)
                compareRow(label: "Front 9 Avg",
                           left: myEngine.avgFront9Score.map { String(format: "%.1f", $0) },
                           right: theirEngine.avgFront9Score.map { String(format: "%.1f", $0) },
                           lowerIsBetter: true)
                Divider().padding(.horizontal, 14)
                compareRow(label: "Back 9 Avg",
                           left: myEngine.avgBack9Score.map { String(format: "%.1f", $0) },
                           right: theirEngine.avgBack9Score.map { String(format: "%.1f", $0) },
                           lowerIsBetter: true)
                Divider().padding(.horizontal, 14)
                compareRow(label: "Best 18",
                           left: myEngine.best18HoleScore.map { "\($0)" },
                           right: theirEngine.best18HoleScore.map { "\($0)" },
                           lowerIsBetter: true)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Stats Comparison

    private var statsComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                compareRow(label: "Avg Putts/Rnd",
                           left: String(format: "%.1f", myEngine.avgPutts),
                           right: String(format: "%.1f", theirEngine.avgPutts),
                           lowerIsBetter: true)
                Divider().padding(.horizontal, 14)
                compareRow(label: "Fairway %",
                           left: String(format: "%.0f%%", myEngine.fairwayPct),
                           right: String(format: "%.0f%%", theirEngine.fairwayPct),
                           lowerIsBetter: false)
                Divider().padding(.horizontal, 14)
                compareRow(label: "GIR %",
                           left: String(format: "%.0f%%", myEngine.girPct),
                           right: String(format: "%.0f%%", theirEngine.girPct),
                           lowerIsBetter: false)
                Divider().padding(.horizontal, 14)
                compareRow(label: "Birdies",
                           left: "\(myEngine.birdieCount)",
                           right: "\(theirEngine.birdieCount)",
                           lowerIsBetter: false)
                Divider().padding(.horizontal, 14)
                compareRow(label: "Pars",
                           left: "\(myEngine.parCount)",
                           right: "\(theirEngine.parCount)",
                           lowerIsBetter: false)
                Divider().padding(.horizontal, 14)
                compareRow(label: "Bogeys",
                           left: "\(myEngine.bogeyCount)",
                           right: "\(theirEngine.bogeyCount)",
                           lowerIsBetter: true)
                Divider().padding(.horizontal, 14)
                compareRow(label: "Double+",
                           left: "\(myEngine.doublePlusCount)",
                           right: "\(theirEngine.doublePlusCount)",
                           lowerIsBetter: true)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Compare Row Helper

    private func compareRow(label: String, left: String?, right: String?, lowerIsBetter: Bool) -> some View {
        let leftVal = left.flatMap { Double($0.replacingOccurrences(of: "%", with: "")) }
        let rightVal = right.flatMap { Double($0.replacingOccurrences(of: "%", with: "")) }
        let winner: Winner = determineWinner(left: leftVal, right: rightVal, lowerIsBetter: lowerIsBetter)

        return HStack {
            Text(left ?? "—")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(winner == .left ? AppTheme.fairwayGreen : .primary)
                .frame(width: 60, alignment: .trailing)

            if winner == .left {
                Image(systemName: "chevron.left")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(AppTheme.fairwayGreen)
                    .frame(width: 14)
            } else {
                Color.clear.frame(width: 14)
            }

            Spacer()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if winner == .right {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(AppTheme.eagle)
                    .frame(width: 14)
            } else {
                Color.clear.frame(width: 14)
            }

            Text(right ?? "—")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(winner == .right ? AppTheme.eagle : .primary)
                .frame(width: 60, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private enum Winner { case left, right, tie, unknown }

    private func determineWinner(left: Double?, right: Double?, lowerIsBetter: Bool) -> Winner {
        guard let l = left, let r = right else { return .unknown }
        if abs(l - r) < 0.01 { return .tie }
        if lowerIsBetter {
            return l < r ? .left : .right
        }
        return l > r ? .left : .right
    }

    // MARK: - Insights

    private var insightsCard: some View {
        let insights = generateInsights()
        return VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            if insights.isEmpty {
                Text("Not enough data for insights yet.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { i, insight in
                        insightRow(insight)
                        if i < insights.count - 1 {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    private func insightRow(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.favorsUser ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
                .foregroundStyle(insight.favorsUser ? AppTheme.fairwayGreen : AppTheme.bogey)
            Text(insight.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(14)
    }

    // MARK: - Hole-by-Hole Comparison

    private var holeByHoleComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Hole Comparison")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            let myStats = myEngine.holeStats
            let theirStats = theirEngine.holeStats
            let count = max(myStats.count, theirStats.count)

            if count > 0 {
                let half = count / 2
                VStack(spacing: 8) {
                    if half > 0 {
                        holeCompareLabel("FRONT \(half)")
                        holeCompareGrid(range: 0..<half, myStats: myStats, theirStats: theirStats)
                    }
                    if count > half {
                        holeCompareLabel("BACK \(count - half)")
                        holeCompareGrid(range: half..<count, myStats: myStats, theirStats: theirStats)
                    }
                }
                .padding(12)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    private func holeCompareLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 2)
    }

    private func holeCompareGrid(range: Range<Int>, myStats: [FriendHoleStat], theirStats: [FriendHoleStat]) -> some View {
        let colCount = max(range.count, 1)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: colCount), spacing: 4) {
            ForEach(range, id: \.self) { i in
                let holeNum = i + 1
                let myStat = i < myStats.count ? myStats[i] : nil
                let theirStat = i < theirStats.count ? theirStats[i] : nil
                holeCompareCell(holeNumber: holeNum, myStat: myStat, theirStat: theirStat)
            }
        }
    }

    private func holeCompareCell(holeNumber: Int, myStat: FriendHoleStat?, theirStat: FriendHoleStat?) -> some View {
        let myAvg = (myStat?.count ?? 0) > 0 ? myStat!.avgScore : nil
        let theirAvg = (theirStat?.count ?? 0) > 0 ? theirStat!.avgScore : nil

        let bgColor: Color
        if let m = myAvg, let t = theirAvg {
            let diff = m - t
            if diff < -0.2 {
                bgColor = AppTheme.fairwayGreen.opacity(0.7)
            } else if diff > 0.2 {
                bgColor = AppTheme.eagle.opacity(0.7)
            } else {
                bgColor = Color(.systemGray4)
            }
        } else {
            bgColor = AppTheme.subtleBackground
        }

        return VStack(spacing: 1) {
            Text("\(holeNumber)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
            if let m = myAvg, let t = theirAvg {
                Text(String(format: "%.0f", m))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                Text(String(format: "%.0f", t))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("—")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.white)
    }

    // MARK: - Insight Generation

    struct Insight {
        let text: String
        let favorsUser: Bool
    }

    private func generateInsights() -> [Insight] {
        var insights: [Insight] = []

        if let myAvg = myEngine.avg18HoleScore, let theirAvg = theirEngine.avg18HoleScore {
            let diff = abs(myAvg - theirAvg)
            if diff >= 0.5 {
                let better = myAvg < theirAvg
                let name = better ? "You average" : "\(friendName) averages"
                insights.append(Insight(
                    text: "\(name) \(String(format: "%.1f", diff)) fewer strokes per 18 holes",
                    favorsUser: better
                ))
            }
        }

        let fwyDiff = myEngine.fairwayPct - theirEngine.fairwayPct
        if abs(fwyDiff) >= 3, myEngine.totalHolesPlayed > 0, theirEngine.totalHolesPlayed > 0 {
            let better = fwyDiff > 0
            let name = better ? "You hit" : "\(friendName) hits"
            insights.append(Insight(
                text: "\(name) \(String(format: "%.0f", abs(fwyDiff)))% more fairways",
                favorsUser: better
            ))
        }

        let girDiff = myEngine.girPct - theirEngine.girPct
        if abs(girDiff) >= 3, myEngine.totalHolesPlayed > 0, theirEngine.totalHolesPlayed > 0 {
            let better = girDiff > 0
            let name = better ? "You hit" : "\(friendName) hits"
            insights.append(Insight(
                text: "\(name) \(String(format: "%.0f", abs(girDiff)))% more greens in regulation",
                favorsUser: better
            ))
        }

        let puttDiff = myEngine.avgPutts - theirEngine.avgPutts
        if abs(puttDiff) >= 0.5, myEngine.roundCount > 0, theirEngine.roundCount > 0 {
            let better = puttDiff < 0
            let name = better ? "You average" : "\(friendName) averages"
            insights.append(Insight(
                text: "\(name) \(String(format: "%.1f", abs(puttDiff))) fewer putts per round",
                favorsUser: better
            ))
        }

        let myPar3 = myEngine.avgScoreOnPar3s
        let theirPar3 = theirEngine.avgScoreOnPar3s
        if myPar3 > 0, theirPar3 > 0, abs(myPar3 - theirPar3) >= 0.2 {
            let better = myPar3 < theirPar3
            let name = better ? "You score" : "\(friendName) scores"
            insights.append(Insight(
                text: "\(name) \(String(format: "%.1f", abs(myPar3 - theirPar3))) better on par 3s",
                favorsUser: better
            ))
        }

        let myPar5 = myEngine.avgScoreOnPar5s
        let theirPar5 = theirEngine.avgScoreOnPar5s
        if myPar5 > 0, theirPar5 > 0, abs(myPar5 - theirPar5) >= 0.3 {
            let better = myPar5 < theirPar5
            let name = better ? "You score" : "\(friendName) scores"
            insights.append(Insight(
                text: "\(name) \(String(format: "%.1f", abs(myPar5 - theirPar5))) better on par 5s",
                favorsUser: better
            ))
        }

        return insights
    }
}
