import SwiftUI

struct CompareView: View {
    let friendName: String
    let friendRounds: [SharedRoundSummary]
    let myRounds: [SharedRoundSummary]

    @State private var selectedCourse: String? = nil

    private var allCourseNames: [String] {
        let courses = Set(friendRounds.map(\.courseName) + myRounds.map(\.courseName))
        return courses.sorted()
    }

    private var filteredFriendRounds: [SharedRoundSummary] {
        guard let course = selectedCourse else { return friendRounds }
        return friendRounds.filter { $0.courseName == course }
    }

    private var filteredMyRounds: [SharedRoundSummary] {
        guard let course = selectedCourse else { return myRounds }
        return myRounds.filter { $0.courseName == course }
    }

    private var myEngine: FriendStatsEngine { FriendStatsEngine(rounds: filteredMyRounds) }
    private var theirEngine: FriendStatsEngine { FriendStatsEngine(rounds: filteredFriendRounds) }

    private var isCourseSelected: Bool { selectedCourse != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headerCard
                if allCourseNames.count > 1 || allCourseNames.count == 1 {
                    courseFilter
                }
                scoringComparison
                statsComparison
                insightsCard
                holeByHoleComparison
                if isCourseSelected {
                    detailedHoleBreakdown
                }
                Color.clear.frame(height: 16)
            }
            .padding()
            .animation(.spring(response: 0.35), value: selectedCourse)
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

    // MARK: - Course Filter

    private var courseFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                courseChip(label: "All Courses", courseName: nil)
                ForEach(allCourseNames, id: \.self) { course in
                    courseChip(label: course, courseName: course)
                }
            }
        }
    }

    private func courseChip(label: String, courseName: String?) -> some View {
        let isActive = selectedCourse == courseName
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3)) {
                selectedCourse = courseName
            }
        } label: {
            HStack(spacing: 5) {
                if courseName != nil {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
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

    // MARK: - Hole-by-Hole Heat Map

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
                    holeCompareKey
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

    private var holeCompareKey: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(AppTheme.fairwayGreen).frame(width: 8, height: 8)
                Text("You lead").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Circle().fill(AppTheme.eagle).frame(width: 8, height: 8)
                Text("\(friendName) leads").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color(.systemGray4)).frame(width: 8, height: 8)
                Text("Even").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
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

    // MARK: - Detailed Hole-by-Hole Breakdown (course-specific)

    private var detailedHoleBreakdown: some View {
        let myStats = myEngine.holeStats
        let theirStats = theirEngine.holeStats
        let count = max(myStats.count, theirStats.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hole-by-Hole Detail")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(selectedCourse ?? "")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.fairwayGreen)
            }
            .padding(.horizontal, 4)

            if count > 0 {
                VStack(spacing: 0) {
                    detailedHoleHeader
                    ForEach(0..<count, id: \.self) { i in
                        let holeNum = i + 1
                        let myStat = i < myStats.count ? myStats[i] : nil
                        let theirStat = i < theirStats.count ? theirStats[i] : nil
                        detailedHoleRow(holeNumber: holeNum, myStat: myStat, theirStat: theirStat)
                        if i < count - 1 {
                            Divider().padding(.horizontal, 8)
                        }
                        if i == 8 && count > 9 {
                            frontBackDivider("BACK 9")
                        }
                    }
                    detailedTotalsRow
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    private var detailedHoleHeader: some View {
        HStack(spacing: 0) {
            Text("Hole")
                .frame(width: 36, alignment: .leading)
            Text("Par")
                .frame(width: 30, alignment: .center)
            Spacer()
            Text("You")
                .foregroundStyle(AppTheme.fairwayGreen)
                .frame(width: 44, alignment: .center)
            Text(String(friendName.prefix(6)))
                .foregroundStyle(AppTheme.eagle)
                .frame(width: 44, alignment: .center)
            Text("+/-")
                .frame(width: 36, alignment: .center)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.subtleBackground)
    }

    private func detailedHoleRow(holeNumber: Int, myStat: FriendHoleStat?, theirStat: FriendHoleStat?) -> some View {
        let myAvg = (myStat?.count ?? 0) > 0 ? myStat!.avgScore : nil
        let theirAvg = (theirStat?.count ?? 0) > 0 ? theirStat!.avgScore : nil
        let par = myStat?.holePar ?? theirStat?.holePar ?? 4

        let diff: Double? = {
            guard let m = myAvg, let t = theirAvg else { return nil }
            return m - t
        }()

        let diffColor: Color = {
            guard let d = diff else { return .secondary }
            if d < -0.2 { return AppTheme.fairwayGreen }
            if d > 0.2 { return AppTheme.bogey }
            return .secondary
        }()

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("\(holeNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(width: 36, alignment: .leading)

                Text("\(par)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .center)

                Spacer()

                Text(myAvg.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(myAvg != nil ? AppTheme.fairwayGreen : Color.gray.opacity(0.4))
                    .frame(width: 44, alignment: .center)

                Text(theirAvg.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(theirAvg != nil ? AppTheme.eagle : Color.gray.opacity(0.4))
                    .frame(width: 44, alignment: .center)

                Text(diff.map { formatDiff($0) } ?? "—")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(diffColor)
                    .frame(width: 36, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if let myStat = myStat, let theirStat = theirStat, myStat.count > 0, theirStat.count > 0 {
                holeDetailBars(myStat: myStat, theirStat: theirStat, par: par)
            }
        }
    }

    private func holeDetailBars(myStat: FriendHoleStat, theirStat: FriendHoleStat, par: Int) -> some View {
        HStack(spacing: 12) {
            if par != 3 {
                miniCompare(label: "FWY", myVal: myStat.fairwayPct, theirVal: theirStat.fairwayPct, format: "%.0f%%", higherIsBetter: true)
            }
            miniCompare(label: "GIR", myVal: myStat.girPct, theirVal: theirStat.girPct, format: "%.0f%%", higherIsBetter: true)
            miniCompare(label: "PUTTS", myVal: myStat.avgPutts, theirVal: theirStat.avgPutts, format: "%.1f", higherIsBetter: false)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func miniCompare(label: String, myVal: Double, theirVal: Double, format: String, higherIsBetter: Bool) -> some View {
        let myBetter = higherIsBetter ? myVal > theirVal + 0.5 : myVal < theirVal - 0.1
        let theirBetter = higherIsBetter ? theirVal > myVal + 0.5 : theirVal < myVal - 0.1

        return VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.tertiary)
            HStack(spacing: 3) {
                Text(String(format: format, myVal))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(myBetter ? AppTheme.fairwayGreen : .secondary)
                Text("/")
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
                Text(String(format: format, theirVal))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theirBetter ? AppTheme.eagle : .secondary)
            }
        }
    }

    private func frontBackDivider(_ label: String) -> some View {
        HStack {
            Rectangle().fill(AppTheme.gold.opacity(0.3)).frame(height: 1)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.gold)
            Rectangle().fill(AppTheme.gold.opacity(0.3)).frame(height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var detailedTotalsRow: some View {
        let myTotal = myEngine.avg18HoleScore
        let theirTotal = theirEngine.avg18HoleScore
        let diff: Double? = {
            guard let m = myTotal, let t = theirTotal else { return nil }
            return m - t
        }()
        let diffColor: Color = {
            guard let d = diff else { return .secondary }
            if d < -0.5 { return AppTheme.fairwayGreen }
            if d > 0.5 { return AppTheme.bogey }
            return .secondary
        }()

        return HStack(spacing: 0) {
            Text("AVG")
                .font(.system(size: 11, weight: .black))
                .frame(width: 36, alignment: .leading)

            Text("")
                .frame(width: 30)

            Spacer()

            Text(myTotal.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 13, weight: .black).monospacedDigit())
                .foregroundStyle(AppTheme.fairwayGreen)
                .frame(width: 44, alignment: .center)

            Text(theirTotal.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 13, weight: .black).monospacedDigit())
                .foregroundStyle(AppTheme.eagle)
                .frame(width: 44, alignment: .center)

            Text(diff.map { formatDiff($0) } ?? "—")
                .font(.system(size: 11, weight: .black).monospacedDigit())
                .foregroundStyle(diffColor)
                .frame(width: 36, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.subtleBackground)
    }

    private func formatDiff(_ diff: Double) -> String {
        if abs(diff) < 0.05 { return "=" }
        return diff > 0 ? String(format: "+%.1f", diff) : String(format: "%.1f", diff)
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

        if isCourseSelected {
            let myStats = myEngine.holeStats
            let theirStats = theirEngine.holeStats
            var myWins = 0, theirWins = 0
            for i in 0..<min(myStats.count, theirStats.count) {
                if myStats[i].count > 0, theirStats[i].count > 0 {
                    let diff = myStats[i].avgScore - theirStats[i].avgScore
                    if diff < -0.2 { myWins += 1 }
                    else if diff > 0.2 { theirWins += 1 }
                }
            }
            if myWins > 0 || theirWins > 0 {
                let leader = myWins > theirWins
                let name = leader ? "You" : friendName
                let wins = leader ? myWins : theirWins
                let total = myWins + theirWins
                insights.append(Insight(
                    text: "\(name) \(leader ? "lead" : "leads") on \(wins) of \(total) contested holes at \(selectedCourse ?? "this course")",
                    favorsUser: leader
                ))
            }
        }

        return insights
    }
}
