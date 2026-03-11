import SwiftUI
import SwiftData

struct HoleEntryView: View {
    @Bindable var score: HoleScore
    let round: Round
    @ObservedObject private var bag = BagManager.shared

    private var info: HoleInfo { score.courseHoleInfo() }
    private var isPar3: Bool { score.par == 3 }
    private var teeName: String { round.teeRaw }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                holeHeader
                step1_teeShot
                if !isPar3 {
                    step2_approachDistance
                    step3_approachResult
                }
                if !score.hitGreen {
                    step4_shortGame
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                step5_putting
                scoreSummary
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: score.hitGreen)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var holeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(info.number)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(AppTheme.fairwayGreen, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.gold, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name.isEmpty ? "Hole \(info.number)" : info.name)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                HStack(spacing: 10) {
                    Label("Par \(score.par)", systemImage: "flag.fill")
                    Label("\(info.yardage(for: teeName))", systemImage: "ruler")
                    if info.mensHdcp > 0 {
                        Label("Hdcp \(info.mensHdcp)", systemImage: "number")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Step 1

    private var step1_teeShot: some View {
        cardSection(step: 1, title: isPar3 ? "Tee shot" : "Drive") {
            VStack(spacing: 12) {
                clubPicker("Club", selection: $score.teeClubRaw, clubs: bag.teeClubs)
                sectionLabel("Where did it end up?")
                if isPar3 {
                    greenResultGrid(binding: $score.teeResultRaw)
                } else {
                    driveResultGrid
                }
            }
        }
    }

    private var driveResultGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            resultChip("Fairway", tag: "fairway", icon: "checkmark", color: AppTheme.fairwayGreen, binding: $score.teeResultRaw)
            resultChip("Rough L", tag: "rough_left", icon: "arrow.left", color: .orange, binding: $score.teeResultRaw)
            resultChip("Rough R", tag: "rough_right", icon: "arrow.right", color: .orange, binding: $score.teeResultRaw)
            resultChip("Native", tag: "native", icon: "leaf", color: .brown, binding: $score.teeResultRaw)
            resultChip("Bunker", tag: "bunker", icon: "circle.circle.fill", color: AppTheme.gold, binding: $score.teeResultRaw)
            resultChip("Drop", tag: "drop", icon: "exclamationmark.triangle", color: AppTheme.double, binding: $score.teeResultRaw)
        }
    }

    private func greenResultGrid(binding: Binding<String>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            resultChip("Green", tag: "green", icon: "flag.fill", color: AppTheme.fairwayGreen, binding: binding)
            resultChip("Short", tag: "short", icon: "arrow.down", color: .orange, binding: binding)
            resultChip("Long", tag: "long", icon: "arrow.up", color: .orange, binding: binding)
            resultChip("Left", tag: "left", icon: "arrow.left", color: .orange, binding: binding)
            resultChip("Right", tag: "right", icon: "arrow.right", color: .orange, binding: binding)
            resultChip("Bunker", tag: "bunker", icon: "circle.circle.fill", color: AppTheme.gold, binding: binding)
        }
    }

    // MARK: - Step 2

    private static let distanceBuckets: [Int] = {
        var buckets = Array(stride(from: 20, through: 270, by: 10))
        buckets.append(275)
        return buckets
    }()

    private var step2_approachDistance: some View {
        cardSection(step: 2, title: "Approach distance") {
            HStack {
                Text("Distance")
                    .font(.subheadline)
                Spacer()
                Picker("Distance", selection: $score.approachDistance) {
                    Text("—").tag(0)
                    ForEach(Self.distanceBuckets, id: \.self) { yds in
                        Text(yds == 275 ? "275+" : "\(yds) yds").tag(yds)
                    }
                }
                .tint(AppTheme.fairwayGreen)
            }
        }
    }

    // MARK: - Step 3

    private var step3_approachResult: some View {
        cardSection(step: 3, title: "Approach") {
            VStack(spacing: 12) {
                clubPicker("Club", selection: $score.approachClubRaw, clubs: bag.approachClubs)
                sectionLabel("Where did it land?")
                greenResultGrid(binding: $score.approachResultRaw)
            }
        }
    }

    // MARK: - Step 4

    private var step4_shortGame: some View {
        cardSection(step: isPar3 ? 2 : 4, title: "Short game") {
            clubPicker("Club to get on", selection: $score.chipClubRaw, clubs: bag.approachClubs)
        }
    }

    // MARK: - Step 5

    private var step5_putting: some View {
        cardSection(step: isPar3 ? (score.hitGreen ? 2 : 3) : (score.hitGreen ? 4 : 5), title: "Putting") {
            VStack(spacing: 14) {
                HStack {
                    Text("Putts")
                        .font(.subheadline)
                    Spacer()
                    stepperRow(value: $score.putts, range: 0...10)
                }
                HStack {
                    Text("1st putt distance")
                        .font(.subheadline)
                    Spacer()
                    TextField("0", value: $score.firstPuttDistance, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.bold().monospacedDigit())
                        .frame(width: 60)
                    Text("ft")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Score

    private var scoreSummary: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                stepperRow(value: $score.score, range: 1...15, large: true)
                Text(score.scoreLabel)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.scoreColor(score.scoreToPar))
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1, height: 50)

            VStack(spacing: 4) {
                Text("PENALTIES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                stepperRow(value: $score.penalties, range: 0...5, large: true)
                Text(" ")
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Reusable

    private func cardSection<Content: View>(step: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(step)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(AppTheme.fairwayGreen, in: Circle())
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clubPicker(_ label: String, selection: Binding<String>, clubs: [Club]) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Picker(label, selection: selection) {
                Text("—").tag("")
                ForEach(clubs, id: \.rawValue) { club in
                    Text(club.displayName).tag(club.rawValue)
                }
            }
            .tint(AppTheme.fairwayGreen)
        }
    }

    private func resultChip(_ label: String, tag: String, icon: String, color: Color, binding: Binding<String>) -> some View {
        let isSelected = binding.wrappedValue == tag
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                binding.wrappedValue = tag
            }
            Haptics.selection()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isSelected ? color.opacity(0.14) : AppTheme.subtleBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? color : .secondary)
            .scaleEffect(isSelected ? 1.0 : 0.97)
        }
        .buttonStyle(.plain)
    }

    private func stepperRow(value: Binding<Int>, range: ClosedRange<Int>, large: Bool = false) -> some View {
        HStack(spacing: 14) {
            Button {
                if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                Haptics.light()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(large ? .title2 : .title3)
                    .foregroundStyle(value.wrappedValue > range.lowerBound ? AppTheme.fairwayGreen : Color(.systemGray4))
            }
            .disabled(value.wrappedValue <= range.lowerBound)

            Text("\(value.wrappedValue)")
                .font(large ? .system(size: 32, weight: .black, design: .rounded) : .title3.bold())
                .monospacedDigit()
                .foregroundStyle(large ? AppTheme.scoreColor(score.scoreToPar) : .primary)
                .frame(width: large ? 44 : 28)
                .contentTransition(.numericText())

            Button {
                if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                Haptics.light()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(large ? .title2 : .title3)
                    .foregroundStyle(AppTheme.fairwayGreen)
            }
            .disabled(value.wrappedValue >= range.upperBound)
        }
    }
}
