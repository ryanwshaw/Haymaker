import SwiftUI

struct ApproachDistanceDetailView: View {
    let stat: ApproachDistanceStat

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                resultBreakdownCard
                clubBreakdownCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(stat.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 16) {
            Text(stat.label)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.fairwayGreen)

            HStack(spacing: 0) {
                bigStat(value: "\(stat.count)", label: "SHOTS")
                Divider().frame(height: 36)
                bigStat(value: String(format: "%.0f%%", stat.greenPct), label: "GREEN HIT")
            }
        }
        .padding(20)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Result Breakdown

    private var resultBreakdownCard: some View {
        let results: [(String, String, Int, Color)] = [
            ("Green", "green", stat.greenCount, AppTheme.fairwayGreen),
            ("Short", "short", stat.shortCount, .orange),
            ("Long", "long", stat.longCount, .orange),
            ("Left", "left", stat.leftCount, .orange),
            ("Right", "right", stat.rightCount, .orange),
            ("Bunker", "bunker", stat.bunkerCount, AppTheme.bogey),
        ]
        let total = max(stat.count, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Result breakdown")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.0) { i, item in
                    let (label, _, count, color) = item
                    if count > 0 {
                        HStack(spacing: 12) {
                            Text(label)
                                .font(.subheadline)
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color.opacity(0.15))
                                    .frame(width: geo.size.width)
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(color)
                                            .frame(width: max(geo.size.width * CGFloat(count) / CGFloat(total), 4))
                                    }
                            }
                            .frame(height: 16)

                            Text("\(count)")
                                .font(.subheadline.bold().monospacedDigit())
                                .frame(width: 24, alignment: .trailing)

                            Text(String(format: "%.0f%%", Double(count) / Double(total) * 100))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Club Breakdown

    private var clubBreakdownCard: some View {
        let clubCounts = Dictionary(grouping: stat.scores.filter { !$0.approachClubRaw.isEmpty }) { $0.approachClubRaw }
            .map { (club: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Clubs used")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            if clubCounts.isEmpty {
                Text("No club data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(clubCounts.enumerated()), id: \.element.club) { i, item in
                        HStack {
                            Text(item.club)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(item.count)x")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if i < clubCounts.count - 1 {
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

    // MARK: - Helpers

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
}
