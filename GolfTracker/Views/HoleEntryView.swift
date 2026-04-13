import SwiftUI
import SwiftData

struct HoleEntryView: View {
    @Bindable var score: HoleScore
    let round: Round
    var onSubmit: ((HoleScore) -> Void)?
    @ObservedObject private var bag = BagManager.shared
    @State private var showDrinkConfirm = false

    @Query(filter: #Predicate<Round> { $0.isComplete }, sort: \Round.date, order: .reverse)
    private var allCompletedRounds: [Round]
    @State private var caddieRecs: [CaddieRecommendation] = []
    @State private var showCaddie = true
    @State private var expandedRecId: UUID?
    @AppStorage("caddieEnabled") private var caddieEnabled = true

    @State private var showBagEditor = false

    private var info: HoleInfo { score.courseHoleInfo() }
    private var isPar3: Bool { score.par == 3 }
    private var teeName: String { round.teeRaw }
    private var bagNeedsSetup: Bool { bag.clubYardages.isEmpty }
    private var courseRoundCount: Int {
        let courseName = round.course?.name
        return allCompletedRounds.filter { $0.course?.name == courseName }.count
    }
    private var hasEnoughData: Bool { courseRoundCount >= 4 }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if caddieEnabled && showCaddie {
                    if bagNeedsSetup {
                        caddieSetupPrompt
                    } else if !caddieRecs.isEmpty {
                        caddieCard
                    }
                }
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
                if score.teeResultRaw.isEmpty == false {
                    submitButton
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: score.hitGreen)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: score.teeResultRaw)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            autoPopulateDefaults()
            computeCaddieRecs()
        }
        .onChange(of: score.holeNumber) { _, _ in
            showCaddie = true
            expandedRecId = nil
            computeCaddieRecs()
            autoPopulateDefaults()
        }
        .onChange(of: score.approachDistance) { _, newDistance in
            autoPopulateApproachClub(distance: newDistance)
        }
        .onChange(of: score.teeResultRaw) { oldValue, newValue in
            if newValue == "drop" && oldValue != "drop" {
                score.penalties += 1
                Haptics.light()
            }
        }
        .alert("Log a drink?", isPresented: $showDrinkConfirm) {
            Button("Cheers!") {
                score.drinksLogged += 1
                Haptics.success()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            let total = round.sortedScores.map(\.drinksLogged).reduce(0, +)
            Text("You've had \(total) drink\(total == 1 ? "" : "s") this round so far.")
        }
    }

    private func autoPopulateDefaults() {
        // Tee club: Driver on par 4/5, caddie will set par 3 after loading
        if score.teeClubRaw.isEmpty && !isPar3 {
            if bag.clubs.contains(.driver) {
                score.teeClubRaw = Club.driver.rawValue
            }
        }

        // Default tee result: Fairway on par 4/5
        if score.teeResultRaw.isEmpty && !isPar3 {
            score.teeResultRaw = "fairway"
        }

        // Default approach result: Green
        if score.approachResultRaw.isEmpty && !isPar3 {
            score.approachResultRaw = "green"
        }

        // Default chip club: Sand Wedge
        if score.chipClubRaw.isEmpty {
            if bag.clubs.contains(.sandWedge) {
                score.chipClubRaw = Club.sandWedge.rawValue
            }
        }
    }

    private func autoPopulateApproachClub(distance: Int) {
        guard distance > 0, score.approachClubRaw.isEmpty else { return }
        if let best = bag.bestClub(for: distance, from: bag.approachClubs) {
            score.approachClubRaw = best.rawValue
        }
    }

    // MARK: - Virtual Caddie

    private func computeCaddieRecs() {
        guard caddieEnabled else { return }
        let holeYds = score.holeYardage > 0 ? score.holeYardage : info.yardage(for: teeName)
        guard holeYds > 0 else { return }

        // Capture values before entering Task to avoid SwiftData cross-thread issues
        let courseName = round.course?.name
        let holeNumber = score.holeNumber
        let holePar = score.par
        let bagRef = bag

        // Yield so the view renders first, then compute in the background of the main actor
        Task { @MainActor in
            await Task.yield()
            let historicalForHole = allCompletedRounds
                .filter { $0.course?.name == courseName }
                .flatMap(\.scores)
                .filter { $0.holeNumber == holeNumber && $0.score > 0 }

            let allCompleted = allCompletedRounds
                .prefix(30) // limit lookback for performance
                .flatMap(\.scores)
                .filter { $0.score > 0 }

            let recs = CaddieEngine.recommend(
                holeYardage: holeYds,
                holePar: holePar,
                holeNumber: holeNumber,
                bag: bagRef,
                historicalScores: historicalForHole,
                allCompletedScores: allCompleted
            )

            withAnimation(.spring(response: 0.35)) {
                caddieRecs = recs
            }

            // If par 3 and no tee club chosen yet, default to caddie's top pick
            if holePar == 3 && score.teeClubRaw.isEmpty, let topRec = recs.first {
                score.teeClubRaw = topRec.club.rawValue
            }
        }
    }

    private var caddieCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "figure.golf")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.mauve, in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Virtual Caddie")
                        .font(.system(size: 13, weight: .bold))
                    Text("Hole \(score.holeNumber) · Par \(score.par) · \(score.holeYardage > 0 ? score.holeYardage : info.yardage(for: teeName)) yds")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { showCaddie = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 10)

            ForEach(caddieRecs) { rec in
                let isExpanded = expandedRecId == rec.id
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            expandedRecId = isExpanded ? nil : rec.id
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(shortName(rec.club))
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(rec.isTopPick ? Color(red: 0.1, green: 0.06, blue: 0.09) : AppTheme.fairwayGreen)
                                .frame(width: 36, height: 36)
                                .background(
                                    rec.isTopPick
                                        ? AnyShapeStyle(LinearGradient(colors: [AppTheme.mauve, AppTheme.mauveLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(AppTheme.fairwayGreen.opacity(0.12))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(rec.club.displayName)
                                        .font(.system(size: 13, weight: .bold))
                                    Text("— \(rec.clubYardage) yds")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Text(rec.reason)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(isExpanded ? nil : 2)
                                Text(rec.confidence)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.mauve)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider().padding(.vertical, 6)

                            if hasEnoughData {
                                ForEach(rec.detailInsights, id: \.self) { insight in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(AppTheme.mauve)
                                            .frame(width: 14)
                                            .padding(.top, 2)
                                        Text(insight)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(["Fairway hit rate with this club: 72%",
                                             "Avg score on this hole: 4.2 (+0.2)",
                                             "You're more accurate from 130 yds than 90 yds",
                                             "2 birdies, 1 bogey in 5 rounds"], id: \.self) { example in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "chart.bar.fill")
                                                .font(.system(size: 9))
                                                .foregroundStyle(AppTheme.mauve.opacity(0.3))
                                                .frame(width: 14)
                                                .padding(.top, 2)
                                            Text(example)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.quaternary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .blur(radius: 1.5)
                                .overlay(alignment: .center) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppTheme.gold)
                                        Text("Log \(4 - courseRoundCount) more round\(4 - courseRoundCount == 1 ? "" : "s") to unlock insights")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                }
                            }

                            Button {
                                score.teeClubRaw = rec.club.rawValue
                                withAnimation(.spring(response: 0.3)) { showCaddie = false }
                                Haptics.selection()
                            } label: {
                                Text("Select \(rec.club.displayName)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(AppTheme.fairwayGreen, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.top, 4)
                        }
                        .padding(.leading, 46)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(rec.isTopPick ? AppTheme.mauve.opacity(0.06) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(rec.isTopPick ? AppTheme.mauve.opacity(0.25) : Color(.systemGray4).opacity(0.5), lineWidth: 1)
                )
                .padding(.bottom, 4)
            }

            Text("Tap a club to expand insights · Select to use it")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var caddieSetupPrompt: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "figure.golf")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.mauve, in: RoundedRectangle(cornerRadius: 7))
                Text("Virtual Caddie")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { showCaddie = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.gold)
                Text("Set up your bag to unlock club recommendations")
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("Add your clubs and average yardages — or import them from a launch monitor CSV — and the caddie will suggest the best club for every hole.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.vertical, 4)

            Button {
                showBagEditor = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bag.fill.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Set Up My Bag")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    LinearGradient(colors: [AppTheme.fairwayGreen, AppTheme.darkGreen],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
        .sheet(isPresented: $showBagEditor) {
            NavigationStack {
                BagEditorView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showBagEditor = false }
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.fairwayGreen)
                        }
                    }
            }
        }
    }

    private func shortName(_ club: Club) -> String {
        switch club {
        case .driver: return "DR"
        case .drivingIron: return "DI"
        case .threeWood: return "3W"
        case .fiveWood: return "5W"
        case .sevenWood: return "7W"
        case .twoHybrid: return "2H"
        case .threeHybrid: return "3H"
        case .fourHybrid: return "4H"
        case .fiveHybrid: return "5H"
        case .hybrid: return "HY"
        case .threeIron: return "3i"
        case .fourIron: return "4i"
        case .fiveIron: return "5i"
        case .sixIron: return "6i"
        case .sevenIron: return "7i"
        case .eightIron: return "8i"
        case .nineIron: return "9i"
        case .pitchingWedge: return "PW"
        case .gapWedge: return "GW"
        case .sandWedge: return "SW"
        case .lobWedge: return "LW"
        case .putter: return "PT"
        }
    }

    // MARK: - Header

    private var holeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(info.number)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(AppTheme.deepGreenGradient, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.gold.opacity(0.5), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(info.name.isEmpty ? "Hole \(info.number)" : info.name)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                HStack(spacing: 10) {
                    Label("Par \(score.par)", systemImage: "flag.fill")
                        .foregroundStyle(AppTheme.fairwayGreen)
                    Label("\(info.yardage(for: teeName)) yds", systemImage: "ruler")
                    if info.mensHdcp > 0 {
                        Label("Hdcp \(info.mensHdcp)", systemImage: "number")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if round.isBoozing {
                drinkButton
            }
        }
        .padding(14)
        .background(
            ZStack {
                AppTheme.cardBackground
                LinearGradient(colors: [AppTheme.fairwayGreen.opacity(0.04), .clear],
                               startPoint: .leading, endPoint: .trailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.fairwayGreen.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private static let drinkBlue = Color(red: 0.4, green: 0.72, blue: 0.95)

    private var drinkButton: some View {
        Button {
            showDrinkConfirm = true
            Haptics.light()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Self.drinkBlue)
                    .shadow(color: Self.drinkBlue.opacity(0.5), radius: 4, y: 1)
                if score.drinksLogged > 0 {
                    Text("\(score.drinksLogged)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color(red: 0.9, green: 0.3, blue: 0.35), in: Circle())
                        .offset(x: 7, y: -5)
                }
            }
            .frame(width: 48, height: 48)
            .background(Self.drinkBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Self.drinkBlue.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            chipClubPicker
        }
    }

    private let quickChipClubs: [(label: String, value: String)] = [
        ("LW", Club.lobWedge.rawValue),
        ("SW", Club.sandWedge.rawValue),
        ("GW", Club.gapWedge.rawValue),
        ("PW", Club.pitchingWedge.rawValue),
        ("Putter", Club.putter.rawValue),
    ]

    private var chipClubPicker: some View {
        let isOther = !score.chipClubRaw.isEmpty && !quickChipClubs.map(\.value).contains(score.chipClubRaw)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Club to get on")
                .font(.subheadline)

            HStack(spacing: 6) {
                ForEach(quickChipClubs, id: \.value) { option in
                    let isSelected = score.chipClubRaw == option.value
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                            score.chipClubRaw = option.value
                        }
                        Haptics.selection()
                    } label: {
                        Text(option.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? AppTheme.fairwayGreen : AppTheme.subtleBackground,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                        if !isOther { score.chipClubRaw = "" }
                    }
                    Haptics.selection()
                } label: {
                    Text("Other")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isOther ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isOther ? AppTheme.mauve : AppTheme.subtleBackground,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
            }

            if isOther || (score.chipClubRaw.isEmpty && !quickChipClubs.map(\.value).contains(score.chipClubRaw)) {
                clubPicker("Select club", selection: $score.chipClubRaw, clubs: bag.approachClubs.filter { club in
                    !quickChipClubs.map(\.value).contains(club.rawValue)
                })
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack {
                Text("Attempts")
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(1...4, id: \.self) { count in
                        let isSelected = score.chipAttempts == count
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                score.chipAttempts = count
                            }
                            Haptics.selection()
                        } label: {
                            Text(count == 1 ? "1" : "\(count)x")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .frame(width: 42, height: 34)
                                .background(
                                    isSelected ? (count >= 3 ? AppTheme.double : AppTheme.fairwayGreen) : AppTheme.subtleBackground,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Step 5

    private var step5_putting: some View {
        cardSection(step: isPar3 ? 2 : (score.hitGreen ? 4 : 5), title: "Putting") {
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

    @State private var showScoreFlash = false

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
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: score.scoreToPar)
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
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(scoreFlashColor.opacity(showScoreFlash ? 0.2 : 0))
                .animation(.easeOut(duration: 0.6), value: showScoreFlash)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .onChange(of: score.score) { _, newScore in
            let toPar = newScore - score.par
            if toPar <= -1 {
                showScoreFlash = true
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showScoreFlash = false
                }
            }
        }
    }

    private var scoreFlashColor: Color {
        score.scoreToPar <= -2 ? AppTheme.eagle : AppTheme.birdie
    }

    // MARK: - Submit

    @State private var submitPressed = false

    private var submitButton: some View {
        Button {
            submitPressed = true
            Haptics.medium()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                submitPressed = false
                onSubmit?(score)
            }
        } label: {
            HStack(spacing: 8) {
                Text("Submit hole \(score.holeNumber)")
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                LinearGradient(colors: [AppTheme.fairwayGreen, AppTheme.darkGreen],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            )
            .scaleEffect(submitPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: submitPressed)
            .shadow(color: AppTheme.fairwayGreen.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
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
