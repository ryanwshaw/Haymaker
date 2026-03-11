import SwiftUI

struct RoundHoleDetailView: View {
    let score: HoleScore
    let round: Round

    private var info: HoleInfo { score.courseHoleInfo() }
    private var isPar3: Bool { score.par == 3 }
    private var teeName: String { round.teeRaw }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                scoreCard
                teeResultCard
                if !isPar3 {
                    approachCard
                }
                if !score.hitGreen && !score.chipClubRaw.isEmpty {
                    shortGameCard
                }
                puttingCard
                if score.penalties > 0 || score.greensideBunker {
                    troubleCard
                }
                Color.clear.frame(height: 16)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Hole \(info.number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(info.number)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(AppTheme.scoreColor(score.scoreToPar), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(info.name.isEmpty ? "Hole \(info.number)" : info.name)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                HStack(spacing: 10) {
                    Label("Par \(score.par)", systemImage: "flag.fill")
                    Label("\(info.yardage(for: teeName)) yds", systemImage: "ruler")
                    if info.mensHdcp > 0 {
                        Label("Hdcp \(info.mensHdcp)", systemImage: "number")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Score

    private var scoreCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(score.score)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.scoreColor(score.scoreToPar))
                Text(score.scoreLabel)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.scoreColor(score.scoreToPar))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Tee Shot / Drive

    private var teeResultCard: some View {
        card(title: isPar3 ? "Tee shot" : "Drive") {
            VStack(spacing: 10) {
                if !score.teeClubRaw.isEmpty {
                    dataRow(label: "Club", value: score.teeClubRaw)
                }
                if !score.teeResultRaw.isEmpty {
                    dataRow(label: "Result", value: teeResultLabel(score.teeResultRaw), valueColor: teeResultColor(score.teeResultRaw))
                }
            }
        }
    }

    // MARK: - Approach

    private var approachCard: some View {
        card(title: "Approach") {
            VStack(spacing: 10) {
                if score.approachDistance > 0 {
                    dataRow(label: "Distance", value: score.approachDistance == 275 ? "275+ yds" : "\(score.approachDistance) yds")
                }
                if !score.approachClubRaw.isEmpty {
                    dataRow(label: "Club", value: score.approachClubRaw)
                }
                if !score.approachResultRaw.isEmpty {
                    dataRow(label: "Result", value: teeResultLabel(score.approachResultRaw), valueColor: teeResultColor(score.approachResultRaw))
                }
            }
        }
    }

    // MARK: - Short Game

    private var shortGameCard: some View {
        card(title: "Short game") {
            dataRow(label: "Club", value: score.chipClubRaw)
        }
    }

    // MARK: - Putting

    private var puttingCard: some View {
        card(title: "Putting") {
            VStack(spacing: 10) {
                dataRow(label: "Putts", value: "\(score.putts)")
                if score.firstPuttDistance > 0 {
                    dataRow(label: "1st putt distance", value: "\(score.firstPuttDistance) ft")
                }
            }
        }
    }

    // MARK: - Trouble

    private var troubleCard: some View {
        card(title: "Trouble") {
            VStack(spacing: 10) {
                if score.penalties > 0 {
                    dataRow(label: "Penalties", value: "\(score.penalties)", valueColor: AppTheme.double)
                }
                if score.greensideBunker {
                    dataRow(label: "Greenside bunker", value: "Yes", valueColor: AppTheme.bogey)
                }
            }
        }
    }

    // MARK: - Reusable

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func dataRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(valueColor)
        }
    }

    private func teeResultLabel(_ raw: String) -> String {
        switch raw {
        case "fairway": return "Fairway"
        case "rough_left": return "Rough Left"
        case "rough_right": return "Rough Right"
        case "native": return "Native"
        case "bunker": return "Bunker"
        case "drop": return "Drop"
        case "green": return "Green"
        case "short": return "Short"
        case "long": return "Long"
        case "left": return "Left"
        case "right": return "Right"
        default: return raw.capitalized
        }
    }

    private func teeResultColor(_ raw: String) -> Color {
        switch raw {
        case "fairway", "green": return AppTheme.fairwayGreen
        case "drop": return AppTheme.double
        case "bunker": return AppTheme.bogey
        case "native": return .brown
        default: return .orange
        }
    }
}
