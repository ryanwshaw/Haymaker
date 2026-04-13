import Foundation

enum BadgeType: String, Codable, CaseIterable, Identifiable {
    // Positive
    case doubleKill
    case shaiHulud
    case greenskeeper
    case shanananananana
    case yesChef
    case rippinDarts
    case fairwayFinder
    case fairwayFrenzy
    case lisanAlGaib
    case bigBird
    case fullCard

    // Negative / comedic
    case animalStyle
    case goblinMode
    case neanderthal
    case iGot5OnIt
    case beachDay
    case quickSleeve
    case helenKeller
    case cuckChair
    case wifesBoyfriend
    case niceShootingSoldier

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .doubleKill: return "DOUBLE KILL"
        case .shaiHulud: return "SHAI-HULUD"
        case .greenskeeper: return "GREENSKEEPER"
        case .shanananananana: return "SHANANANANANANA"
        case .yesChef: return "YES CHEF"
        case .rippinDarts: return "RIPPIN' DARTS"
        case .fairwayFinder: return "FAIRWAY FINDER"
        case .fairwayFrenzy: return "FAIRWAY FRENZY"
        case .lisanAlGaib: return "LISAN AL GAIB"
        case .bigBird: return "BIG BIRD"
        case .fullCard: return "FULL CARD"
        case .animalStyle: return "ANIMAL STYLE"
        case .goblinMode: return "GOBLIN MODE"
        case .neanderthal: return "NEANDERTHAL"
        case .iGot5OnIt: return "I GOT 5 ON IT"
        case .beachDay: return "BEACH DAY"
        case .quickSleeve: return "QUICK SLEEVE"
        case .helenKeller: return "HELEN KELLER"
        case .cuckChair: return "CUCK CHAIR"
        case .wifesBoyfriend: return "WIFE'S BOYFRIEND"
        case .niceShootingSoldier: return "NICE SHOOTING SOLDIER!"
        }
    }

    var subtitle: String {
        switch self {
        case .doubleKill: return "2 birdies in a row"
        case .shaiHulud: return "Up & down from a greenside bunker"
        case .greenskeeper: return "Under 20 putts in a round"
        case .shanananananana: return "5 one-putts in a row"
        case .yesChef: return "10 one-putts in a row"
        case .rippinDarts: return "5 greens in regulation in a row"
        case .fairwayFinder: return "5 fairways in a row"
        case .fairwayFrenzy: return "10 fairways in a row"
        case .lisanAlGaib: return "5 up & downs from greenside bunker in a round"
        case .bigBird: return "Eagle on a hole"
        case .fullCard: return "Birdied every hole at this course"
        case .animalStyle: return "Back to back double bogeys"
        case .goblinMode: return "Back to back triple bogeys"
        case .neanderthal: return "Quad bogey on a hole"
        case .iGot5OnIt: return "Quintuple bogey on a hole"
        case .beachDay: return "5 bunkers in a round"
        case .quickSleeve: return "Multiple drops on a single hole"
        case .helenKeller: return "Miss every green in regulation"
        case .cuckChair: return "9-hole score over 50"
        case .wifesBoyfriend: return "18-hole score over 100"
        case .niceShootingSoldier: return "Miss 10 fairways in a row"
        }
    }

    var imageName: String {
        switch self {
        case .doubleKill: return "BadgeDoubleKill"
        case .shaiHulud: return "BadgeShaiHulud"
        case .lisanAlGaib: return "BadgeLisanAlGaib"
        case .shanananananana: return "BadgeShanananananana"
        case .cuckChair: return "BadgeCuckChair"
        case .helenKeller: return "BadgeHelenKeller"
        case .bigBird: return "BadgeBigBird"
        case .fullCard: return "Badge_fullCard"
        case .animalStyle: return "BadgeAnimalStyle"
        case .goblinMode: return "BadgeGoblinMode"
        case .iGot5OnIt: return "BadgeIGot5OnIt"
        case .quickSleeve: return "BadgeQuickSleeve"
        default: return "Badge_\(rawValue)"
        }
    }

    var isCircularImage: Bool {
        switch self {
        case .shaiHulud, .lisanAlGaib, .shanananananana, .helenKeller,
             .bigBird, .goblinMode:
            return true
        default:
            return false
        }
    }

    var placeholderSymbol: String {
        switch self {
        case .doubleKill: return "flame.fill"
        case .shaiHulud: return "waveform.path"
        case .greenskeeper: return "circle.dotted.circle"
        case .shanananananana: return "hand.point.down.fill"
        case .yesChef: return "frying.pan.fill"
        case .rippinDarts: return "target"
        case .fairwayFinder: return "road.lanes"
        case .fairwayFrenzy: return "road.lanes.curved.right"
        case .lisanAlGaib: return "sun.max.fill"
        case .bigBird: return "bird.fill"
        case .fullCard: return "star.fill"
        case .animalStyle: return "pawprint.fill"
        case .goblinMode: return "theatermasks.fill"
        case .neanderthal: return "figure.walk"
        case .iGot5OnIt: return "hand.raised.fingers.spread.fill"
        case .beachDay: return "beach.umbrella.fill"
        case .quickSleeve: return "bag.fill"
        case .helenKeller: return "eye.slash.fill"
        case .cuckChair: return "chair.lounge.fill"
        case .wifesBoyfriend: return "heart.slash.fill"
        case .niceShootingSoldier: return "scope"
        }
    }

    var isPositive: Bool {
        switch self {
        case .doubleKill, .shaiHulud, .greenskeeper, .shanananananana,
             .yesChef, .rippinDarts, .fairwayFinder, .fairwayFrenzy,
             .lisanAlGaib, .bigBird, .fullCard:
            return true
        default:
            return false
        }
    }
}

struct EarnedBadge: Codable, Identifiable {
    var id: String { "\(type.rawValue)-\(earnedAt.timeIntervalSince1970)" }
    let type: BadgeType
    let earnedAt: Date
    let roundDate: Date?
    let courseName: String?
    let holeNumbers: [Int]
}

// MARK: - Badge Manager

final class BadgeManager: ObservableObject {
    static let shared = BadgeManager()

    @Published var earnedBadges: [EarnedBadge] = []
    @Published var pendingBadge: BadgeType? = nil

    private var sessionAwarded: Set<String> = []
    private var pendingQueue: [BadgeType] = []

    private let storageKey = "earnedBadges"

    private init() {
        load()
    }

    var badgeCounts: [BadgeType: Int] {
        var counts: [BadgeType: Int] = [:]
        for badge in earnedBadges {
            counts[badge.type, default: 0] += 1
        }
        return counts
    }

    func count(for type: BadgeType) -> Int {
        earnedBadges.filter { $0.type == type }.count
    }

    func resetSession() {
        sessionAwarded.removeAll()
        pendingQueue.removeAll()
    }

    private func sessionKey(_ type: BadgeType, holes: [Int]) -> String {
        "\(type.rawValue)-\(holes.map(String.init).joined(separator: ","))"
    }

    func award(_ type: BadgeType, roundDate: Date?, courseName: String?, holeNumbers: [Int]) {
        let key = sessionKey(type, holes: holeNumbers)
        guard !sessionAwarded.contains(key) else { return }
        sessionAwarded.insert(key)

        let badge = EarnedBadge(
            type: type,
            earnedAt: .now,
            roundDate: roundDate,
            courseName: courseName,
            holeNumbers: holeNumbers
        )
        earnedBadges.append(badge)
        save()

        if pendingBadge == nil {
            pendingBadge = type
        } else {
            pendingQueue.append(type)
        }
    }

    func clearPending() {
        pendingBadge = nil
        if !pendingQueue.isEmpty {
            let next = pendingQueue.removeFirst()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.pendingBadge = next
            }
        }
    }

    // MARK: - Detection

    func checkForBadges(score: HoleScore, allScores: [HoleScore], currentIndex: Int, round: Round, courseHistoricalScores: [HoleScore] = []) {
        guard !score.teeResultRaw.isEmpty else { return }

        let played = completedScores(allScores, through: currentIndex)

        checkSingleHoleBadges(score: score, round: round)
        checkConsecutiveBadges(allScores: played, currentIndex: currentIndex, round: round)
        checkRoundAccumulationBadges(played: played, round: round)
        checkFullCard(score: score, round: round, courseHistoricalScores: courseHistoricalScores)
    }

    private func completedScores(_ all: [HoleScore], through index: Int) -> [HoleScore] {
        Array(all.prefix(index + 1)).filter { !$0.teeResultRaw.isEmpty }
    }

    // MARK: Single-hole badges

    private func checkSingleHoleBadges(score: HoleScore, round: Round) {
        checkShaiHulud(score: score, round: round)
        checkBigBird(score: score, round: round)
        checkNeanderthal(score: score, round: round)
        checkIGot5OnIt(score: score, round: round)
        checkQuickSleeve(score: score, round: round)
    }

    private func checkShaiHulud(score: HoleScore, round: Round) {
        let wasInGreensideBunker: Bool
        if score.par == 3 {
            wasInGreensideBunker = score.teeResultRaw == "bunker"
        } else {
            wasInGreensideBunker = score.approachResultRaw == "bunker"
        }
        guard wasInGreensideBunker, score.putts == 1 else { return }
        award(.shaiHulud, roundDate: round.date, courseName: round.courseName, holeNumbers: [score.holeNumber])
    }

    private func checkBigBird(score: HoleScore, round: Round) {
        guard score.scoreToPar <= -2 else { return }
        award(.bigBird, roundDate: round.date, courseName: round.courseName, holeNumbers: [score.holeNumber])
    }

    private func checkNeanderthal(score: HoleScore, round: Round) {
        guard score.scoreToPar >= 4 else { return }
        award(.neanderthal, roundDate: round.date, courseName: round.courseName, holeNumbers: [score.holeNumber])
    }

    private func checkIGot5OnIt(score: HoleScore, round: Round) {
        guard score.scoreToPar >= 5 else { return }
        award(.iGot5OnIt, roundDate: round.date, courseName: round.courseName, holeNumbers: [score.holeNumber])
    }

    private func checkQuickSleeve(score: HoleScore, round: Round) {
        guard score.penalties >= 2 else { return }
        award(.quickSleeve, roundDate: round.date, courseName: round.courseName, holeNumbers: [score.holeNumber])
    }

    // MARK: Consecutive-hole badges

    private func checkConsecutiveBadges(allScores: [HoleScore], currentIndex: Int, round: Round) {
        guard currentIndex > 0 else { return }

        checkDoubleKill(allScores: allScores, currentIndex: currentIndex, round: round)
        checkAnimalStyle(allScores: allScores, currentIndex: currentIndex, round: round)
        checkGoblinMode(allScores: allScores, currentIndex: currentIndex, round: round)
        checkStreak(allScores: allScores, currentIndex: currentIndex, round: round,
                    count: 5, type: .shanananananana) { $0.putts == 1 }
        checkStreak(allScores: allScores, currentIndex: currentIndex, round: round,
                    count: 10, type: .yesChef) { $0.putts == 1 }
        checkStreak(allScores: allScores, currentIndex: currentIndex, round: round,
                    count: 5, type: .rippinDarts) { $0.hitGreen }
        checkStreak(allScores: allScores, currentIndex: currentIndex, round: round,
                    count: 5, type: .fairwayFinder) { $0.par != 3 && $0.hitFairway }
        checkStreak(allScores: allScores, currentIndex: currentIndex, round: round,
                    count: 10, type: .fairwayFrenzy) { $0.par != 3 && $0.hitFairway }
        checkMissStreak(allScores: allScores, currentIndex: currentIndex, round: round)
    }

    private func checkDoubleKill(allScores: [HoleScore], currentIndex: Int, round: Round) {
        guard currentIndex > 0, currentIndex < allScores.count else { return }
        let current = allScores[currentIndex]
        let previous = allScores[currentIndex - 1]
        guard !current.teeResultRaw.isEmpty, !previous.teeResultRaw.isEmpty else { return }
        guard current.scoreToPar <= -1, previous.scoreToPar <= -1 else { return }
        award(.doubleKill, roundDate: round.date, courseName: round.courseName,
              holeNumbers: [previous.holeNumber, current.holeNumber])
    }

    private func checkAnimalStyle(allScores: [HoleScore], currentIndex: Int, round: Round) {
        guard currentIndex > 0, currentIndex < allScores.count else { return }
        let current = allScores[currentIndex]
        let previous = allScores[currentIndex - 1]
        guard !current.teeResultRaw.isEmpty, !previous.teeResultRaw.isEmpty else { return }
        guard current.scoreToPar >= 2, previous.scoreToPar >= 2 else { return }
        award(.animalStyle, roundDate: round.date, courseName: round.courseName,
              holeNumbers: [previous.holeNumber, current.holeNumber])
    }

    private func checkGoblinMode(allScores: [HoleScore], currentIndex: Int, round: Round) {
        guard currentIndex > 0, currentIndex < allScores.count else { return }
        let current = allScores[currentIndex]
        let previous = allScores[currentIndex - 1]
        guard !current.teeResultRaw.isEmpty, !previous.teeResultRaw.isEmpty else { return }
        guard current.scoreToPar >= 3, previous.scoreToPar >= 3 else { return }
        award(.goblinMode, roundDate: round.date, courseName: round.courseName,
              holeNumbers: [previous.holeNumber, current.holeNumber])
    }

    /// Generic streak checker: awards if the last `count` completed scores all satisfy `predicate`.
    private func checkStreak(allScores: [HoleScore], currentIndex: Int, round: Round,
                             count: Int, type: BadgeType, predicate: (HoleScore) -> Bool) {
        guard allScores.count >= count else { return }
        let window = allScores.suffix(count)
        guard window.allSatisfy({ !$0.teeResultRaw.isEmpty && predicate($0) }) else { return }
        let holes = window.map(\.holeNumber)
        award(type, roundDate: round.date, courseName: round.courseName, holeNumbers: holes)
    }

    /// For fairway-specific streaks, only count non-par-3 holes.
    private func checkMissStreak(allScores: [HoleScore], currentIndex: Int, round: Round) {
        let nonPar3 = allScores.filter { $0.par != 3 && !$0.teeResultRaw.isEmpty }
        guard nonPar3.count >= 10 else { return }
        let last10 = nonPar3.suffix(10)
        guard last10.allSatisfy({ !$0.hitFairway }) else { return }
        let holes = last10.map(\.holeNumber)
        award(.niceShootingSoldier, roundDate: round.date, courseName: round.courseName, holeNumbers: holes)
    }

    // MARK: Round-accumulation badges

    private func checkRoundAccumulationBadges(played: [HoleScore], round: Round) {
        checkBeachDay(played: played, round: round)
        checkLisanAlGaib(played: played, round: round)
        checkGreenskeeper(played: played, round: round)
        checkHelenKeller(played: played, round: round)
        checkCuckChair(played: played, round: round)
        checkWifesBoyfriend(played: played, round: round)
    }

    private func checkBeachDay(played: [HoleScore], round: Round) {
        let bunkerCount = played.filter { $0.greensideBunker || $0.teeResultRaw == "bunker" || $0.approachResultRaw == "bunker" }.count
        guard bunkerCount >= 5 else { return }
        award(.beachDay, roundDate: round.date, courseName: round.courseName, holeNumbers: [0])
    }

    private func checkLisanAlGaib(played: [HoleScore], round: Round) {
        let shaiCount = played.filter { score in
            let inBunker: Bool
            if score.par == 3 {
                inBunker = score.teeResultRaw == "bunker"
            } else {
                inBunker = score.approachResultRaw == "bunker"
            }
            return inBunker && score.putts == 1
        }.count
        guard shaiCount >= 5 else { return }
        award(.lisanAlGaib, roundDate: round.date, courseName: round.courseName, holeNumbers: [0])
    }

    private func checkGreenskeeper(played: [HoleScore], round: Round) {
        guard played.count >= 18 else { return }
        let totalPutts = played.reduce(0) { $0 + $1.putts }
        guard totalPutts < 20 else { return }
        award(.greenskeeper, roundDate: round.date, courseName: round.courseName, holeNumbers: [0])
    }

    private func checkHelenKeller(played: [HoleScore], round: Round) {
        guard played.count >= 18 else { return }
        guard played.allSatisfy({ !$0.hitGreen }) else { return }
        award(.helenKeller, roundDate: round.date, courseName: round.courseName, holeNumbers: [0])
    }

    private func checkCuckChair(played: [HoleScore], round: Round) {
        if played.count >= 9 {
            let front9 = played.prefix(9)
            let front9Score = front9.reduce(0) { $0 + $1.score }
            if front9Score > 50 {
                award(.cuckChair, roundDate: round.date, courseName: round.courseName,
                      holeNumbers: Array(front9.map(\.holeNumber)))
            }
        }
        if played.count >= 18 {
            let back9 = played.dropFirst(9).prefix(9)
            let back9Score = back9.reduce(0) { $0 + $1.score }
            if back9Score > 50 {
                award(.cuckChair, roundDate: round.date, courseName: round.courseName,
                      holeNumbers: Array(back9.map(\.holeNumber)))
            }
        }
    }

    private func checkWifesBoyfriend(played: [HoleScore], round: Round) {
        guard played.count >= 18 else { return }
        let total = played.reduce(0) { $0 + $1.score }
        guard total > 100 else { return }
        award(.wifesBoyfriend, roundDate: round.date, courseName: round.courseName, holeNumbers: [0])
    }

    // MARK: Full Card — birdied every hole on the course

    private func checkFullCard(score: HoleScore, round: Round, courseHistoricalScores: [HoleScore]) {
        // Only check when a birdie (or better) is scored
        guard score.scoreToPar <= -1 else { return }

        let courseName = round.courseName

        // Only award once per course
        let alreadyEarned = earnedBadges.contains { $0.type == .fullCard && $0.courseName == courseName }
        guard !alreadyEarned else { return }

        // Build the set of hole numbers that have at least one birdie in history + this score
        var birdiedHoles = Set(
            courseHistoricalScores
                .filter { $0.scoreToPar <= -1 }
                .map(\.holeNumber)
        )
        birdiedHoles.insert(score.holeNumber)

        // Check if all 18 holes are covered
        let allHoles = Set(1...18)
        guard birdiedHoles.isSuperset(of: allHoles) else { return }

        award(.fullCard, roundDate: round.date, courseName: courseName, holeNumbers: Array(allHoles))
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(earnedBadges) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let badges = try? JSONDecoder().decode([EarnedBadge].self, from: data) else { return }
        earnedBadges = badges
    }
}
