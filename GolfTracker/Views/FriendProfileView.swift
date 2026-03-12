import SwiftUI
import SwiftData
import CloudKit

struct FriendProfileView: View {
    let friendship: CKRecord
    @ObservedObject private var ck = CloudKitManager.shared
    @Query(sort: \Round.date, order: .reverse) private var myRounds: [Round]

    @State private var friendRounds: [SharedRoundSummary] = []
    @State private var isLoading = true
    @State private var friendProfile: CKRecord?
    @State private var selectedTee: String? = nil

    private var friendName: String { ck.friendDisplayName(from: friendship) }

    private var engine: FriendStatsEngine {
        FriendStatsEngine.filtered(rounds: friendRounds, tee: selectedTee)
    }

    private var availableTees: [String] {
        Array(Set(friendRounds.map(\.tee))).sorted()
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading \(friendName)'s rounds...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if friendRounds.isEmpty {
                emptyState
            } else {
                statsContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(friendName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFriendData() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.gold.opacity(0.4))
            Text("No rounds yet")
                .font(.title3.bold())
            Text("\(friendName) hasn't published any rounds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                teeFilter
                overviewCard
                scoringBreakdown
                heatMapSection
                compareButton
                roundsList
                Color.clear.frame(height: 16)
            }
            .padding()
        }
    }

    // MARK: - Tee Filter

    private var teeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                teeChip(label: "All", teeName: nil)
                ForEach(availableTees, id: \.self) { tee in
                    teeChip(label: tee, teeName: tee)
                }
            }
        }
    }

    private func teeChip(label: String, teeName: String?) -> some View {
        let isActive = selectedTee == teeName
        return Button {
            Haptics.selection()
            selectedTee = teeName
        } label: {
            Text(label)
                .font(.subheadline.bold())
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

            HStack(spacing: 0) {
                overviewStat(value: String(format: "%.1f", engine.avgPutts), label: "PUTTS/RND")
                statDivider
                overviewStat(value: String(format: "%.0f%%", engine.fairwayPct), label: "FWY")
                statDivider
                overviewStat(value: String(format: "%.0f%%", engine.girPct), label: "GIR")
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
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
            let half = stats.count / 2

            VStack(spacing: 4) {
                if half > 0 {
                    heatMapLabel("FRONT \(half)")
                    heatMapRow(stats: Array(stats.prefix(half)))
                    heatMapLabel("BACK \(stats.count - half)")
                    heatMapRow(stats: Array(stats.suffix(stats.count - half)))
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

    private func heatMapRow(stats: [FriendHoleStat]) -> some View {
        let columnCount = max(stats.count, 1)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount), spacing: 4) {
            ForEach(stats, id: \.holeNumber) { stat in
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
                .foregroundStyle(stat.count > 0 ? .white : .secondary)
            }
        }
    }

    // MARK: - Compare Button

    private var compareButton: some View {
        NavigationLink {
            CompareView(
                friendName: friendName,
                friendRounds: friendRounds,
                myRounds: myRounds.filter(\.isComplete).map { SharedRoundSummary.from($0) }
            )
        } label: {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.body.bold())
                Text("Compare with \(friendName)")
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(AppTheme.headerGradient, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: AppTheme.darkGreen.opacity(0.3), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rounds List

    private var roundsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Rounds")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                let displayRounds = engine.rounds.prefix(20)
                ForEach(Array(displayRounds.enumerated()), id: \.element.id) { i, round in
                    friendRoundRow(round)
                    if i < displayRounds.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    private func friendRoundRow(_ round: SharedRoundSummary) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(round.totalScore)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Text(round.scoreToParString)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.scoreColor(round.scoreToPar))
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(round.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.bold())
                Text("\(round.tee) · \(round.courseName)\(round.holesPlayed < 18 ? " · \(round.holesPlayed)h" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(round.totalPutts)")
                    .font(.caption.monospacedDigit())
                Text("PUTTS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Data Loading

    private func loadFriendData() async {
        isLoading = true
        defer { isLoading = false }

        friendProfile = await ck.friendProfile(from: friendship)
        if let profile = friendProfile {
            friendRounds = await ck.fetchFriendRounds(friendProfile: profile)
        }
    }
}
