import SwiftUI

struct RoundDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let round: Round
    @State private var showDeleteConfirm = false
    @State private var expandedHole: Int? = nil
    @State private var editingRound: Round? = nil
    @State private var showEditingRound = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryHeader
                    .staggeredAppear(index: 0)
                scoreSparkline
                    .staggeredAppear(index: 1)
                scorecardGrid
                    .staggeredAppear(index: 2)
                scorecardList
                    .staggeredAppear(index: 3)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(round.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        round.isComplete = false
                        try? modelContext.save()
                        editingRound = round
                        showEditingRound = true
                    } label: {
                        Label("Edit round", systemImage: "pencil")
                    }
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
        .fullScreenCover(isPresented: $showEditingRound) {
            if let editRound = editingRound {
                ActiveRoundView(round: editRound) {
                    editRound.isComplete = true
                    try? modelContext.save()
                    showEditingRound = false
                    editingRound = nil
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

    // MARK: - Summary Header with Score Ring

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(round.displayTeeColor).frame(width: 10, height: 10)
                Text("\(round.teeRaw) tees · \(round.courseName) · \(round.holesPlayed) holes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                scoreRing
                VStack(alignment: .leading, spacing: 10) {
                    statRow(icon: "flag.fill", label: "Fairways", value: String(format: "%.0f%%", round.fairwayPct))
                    statRow(icon: "circle.inset.filled", label: "GIR", value: String(format: "%.0f%%", round.girPct))
                    statRow(icon: "smallcircle.filled.circle", label: "Putts", value: "\(round.totalPutts)")
                    if round.isBoozing {
                        statRow(icon: "wineglass.fill", label: "Drinks", value: "\(round.totalDrinks)")
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var scoreRing: some View {
        let totalPar = round.sortedScores.map(\.par).reduce(0, +)
        let progress = totalPar > 0 ? min(Double(round.totalScore) / Double(totalPar + 10), 1.0) : 0.5
        let ringColor = AppTheme.scoreColor(round.scoreToPar)

        return ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: 8)
                .frame(width: 100, height: 100)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(round.totalScore)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                Text(round.scoreToParString)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ringColor)
            }
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.fairwayGreen)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(AppTheme.fairwayGreen)
        }
    }

    // MARK: - Score Sparkline

    private var scoreSparkline: some View {
        let scores = round.sortedScores
        guard scores.count >= 2 else { return AnyView(EmptyView()) }

        let pars = scores.map(\.par)
        let vals = scores.map { Double($0.score) }
        let parVals = pars.map { Double($0) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Score vs Par")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                GeometryReader { geo in
                    let w = geo.size.width
                    let h: CGFloat = 50
                    let allVals = vals + parVals
                    let minV = (allVals.min() ?? 2) - 1
                    let maxV = (allVals.max() ?? 6) + 1
                    let range = max(maxV - minV, 1)
                    let stepX = w / CGFloat(max(vals.count - 1, 1))

                    let scorePoints = vals.enumerated().map { i, v in
                        CGPoint(x: stepX * CGFloat(i),
                                y: h - CGFloat((v - minV) / range) * h)
                    }
                    let parPoints = parVals.enumerated().map { i, v in
                        CGPoint(x: stepX * CGFloat(i),
                                y: h - CGFloat((v - minV) / range) * h)
                    }

                    ZStack {
                        Path { path in
                            path.move(to: parPoints[0])
                            for pt in parPoints.dropFirst() { path.addLine(to: pt) }
                        }
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                        Path { path in
                            path.move(to: scorePoints[0])
                            for pt in scorePoints.dropFirst() { path.addLine(to: pt) }
                        }
                        .stroke(AppTheme.fairwayGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        ForEach(Array(scorePoints.enumerated()), id: \.offset) { i, pt in
                            let toPar = scores[i].scoreToPar
                            Circle()
                                .fill(AppTheme.scoreColor(toPar))
                                .frame(width: 5, height: 5)
                                .position(pt)
                        }
                    }
                    .frame(height: h)
                }
                .frame(height: 50)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    // MARK: - Visual Scorecard Grid

    private var scorecardGrid: some View {
        let scores = round.sortedScores
        let half = min(9, scores.count)
        let front = Array(scores.prefix(half))
        let back = scores.count > 9 ? Array(scores.suffix(from: 9)) : []

        return VStack(alignment: .leading, spacing: 8) {
            Text("Scorecard")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if !front.isEmpty {
                    scorecardGridRow(label: "OUT", scores: front)
                }
                if !back.isEmpty {
                    Divider()
                    scorecardGridRow(label: "IN", scores: back)
                }
            }
            .padding(8)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    private func scorecardGridRow(label: String, scores: [HoleScore]) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 24)
                ForEach(scores, id: \.id) { score in
                    Text("\(score.holeNumber)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
            HStack(spacing: 2) {
                Text("PAR")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24)
                ForEach(scores, id: \.id) { score in
                    Text("\(score.par)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                }
                Text("\(scores.map(\.par).reduce(0, +))")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 24)
                ForEach(scores, id: \.id) { score in
                    Text("\(score.score)")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(score.scoreToPar == 0 ? Color.primary : Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            AppTheme.scoreColor(score.scoreToPar)
                                .opacity(score.scoreToPar == 0 ? 0.08 : 0.85),
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                }
                Text("\(scores.map(\.score).reduce(0, +))")
                    .font(.system(size: 11, weight: .black, design: .rounded).monospacedDigit())
                    .frame(width: 30)
            }
        }
    }

    // MARK: - Hole List (expandable)

    private var scorecardList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hole detail")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(round.sortedScores.enumerated()), id: \.element.id) { i, score in
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                expandedHole = expandedHole == score.holeNumber ? nil : score.holeNumber
                            }
                            Haptics.light()
                        } label: {
                            holeRow(score: score)
                        }
                        .buttonStyle(.plain)

                        if expandedHole == score.holeNumber {
                            holeExpandedDetail(score: score)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

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
        let info = score.courseHoleInfo()
        let isExpanded = expandedHole == score.holeNumber
        return HStack(spacing: 10) {
            Text("\(info.number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(AppTheme.scoreColor(score.scoreToPar), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(info.name.isEmpty ? "Hole \(info.number)" : info.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                Text("Par \(score.par) · \(info.yardage(for: round.teeRaw)) yds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                if score.par != 3 {
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
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func holeExpandedDetail(score: HoleScore) -> some View {
        VStack(spacing: 8) {
            if !score.teeResultRaw.isEmpty {
                detailPill(label: "Tee Shot", value: score.teeResultRaw.replacingOccurrences(of: "_", with: " ").capitalized,
                           sub: score.teeClubRaw.isEmpty ? nil : score.teeClubRaw)
            }
            if score.approachDistance > 0 {
                detailPill(label: "Approach", value: "\(score.approachDistance) yds → \(score.approachResultRaw.replacingOccurrences(of: "_", with: " ").capitalized)",
                           sub: score.approachClubRaw.isEmpty ? nil : score.approachClubRaw)
            }
            if !score.chipClubRaw.isEmpty {
                detailPill(label: "Short Game", value: score.chipClubRaw, sub: nil)
            }
            detailPill(label: "Putting", value: "\(score.putts) putts · \(score.firstPuttDistance) ft first",
                        sub: nil)
            if score.penalties > 0 {
                detailPill(label: "Penalties", value: "\(score.penalties)", sub: nil)
            }
        }
        .padding(.horizontal, 50)
        .padding(.bottom, 10)
    }

    private func detailPill(label: String, value: String, sub: String?) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 65, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                if let s = sub {
                    Text(s)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
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
