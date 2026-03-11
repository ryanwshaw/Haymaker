import SwiftUI

struct RoundDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let round: Round
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                scorecardSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(round.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete round", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete this round?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(round)
                try? modelContext.save()
                Haptics.medium()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete this round and all hole data.")
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(round.tee.color).frame(width: 10, height: 10)
                        Text("\(round.tee.rawValue) tees")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(round.totalScore)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                        Text(round.scoreToParString)
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.scoreColor(round.scoreToPar))
                    }
                }
                Spacer()
            }
            HStack(spacing: 0) {
                miniStat(value: String(format: "%.0f%%", round.fairwayPct), label: "Fairways")
                Divider().frame(height: 32)
                miniStat(value: String(format: "%.0f%%", round.girPct), label: "GIR")
                Divider().frame(height: 32)
                miniStat(value: "\(round.totalPutts)", label: "Putts")
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.fairwayGreen)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var scorecardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scorecard")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(round.sortedScores.enumerated()), id: \.element.id) { i, score in
                    NavigationLink {
                        RoundHoleDetailView(score: score, tee: round.tee)
                    } label: {
                        holeRow(score: score)
                    }
                    .buttonStyle(.plain)

                    if i < round.sortedScores.count - 1 {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    private func holeRow(score: HoleScore) -> some View {
        let info = score.holeInfo
        return HStack(spacing: 10) {
            Text("\(info.number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(AppTheme.scoreColor(score.scoreToPar), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(info.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                Text("Par \(info.par) · \(info.yardage(for: round.tee)) yds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                if info.par != 3 {
                    chipTag(score.hitFairway ? "FWY" : "MISS", color: score.hitFairway ? AppTheme.fairwayGreen : .secondary)
                }
                chipTag(score.hitGreen ? "GIR" : "MISS", color: score.hitGreen ? AppTheme.fairwayGreen : .secondary)
                Text("\(score.putts)P")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text("\(score.score)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppTheme.scoreColor(score.scoreToPar))
                    .frame(width: 24, alignment: .trailing)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func chipTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}
