import Foundation

struct StatsEngine {
    let rounds: [Round]

    var allScores: [HoleScore] {
        rounds.flatMap(\.sortedScores)
    }

    // MARK: - Overall

    var roundCount: Int { rounds.count }

    var avgPutts: Double {
        guard !rounds.isEmpty else { return 0 }
        return Double(rounds.map(\.totalPutts).reduce(0, +)) / Double(rounds.count)
    }

    // MARK: - Scoring Averages (only from qualifying rounds)

    private var full18Rounds: [Round] { rounds.filter(\.hasFull18) }
    private var front9Rounds: [Round] { rounds.filter(\.hasFront9) }
    private var back9Rounds: [Round] { rounds.filter(\.hasBack9) }

    var avg18HoleScore: Double? {
        guard !full18Rounds.isEmpty else { return nil }
        return Double(full18Rounds.map(\.totalScore).reduce(0, +)) / Double(full18Rounds.count)
    }

    var avgFront9Score: Double? {
        guard !front9Rounds.isEmpty else { return nil }
        return Double(front9Rounds.map(\.front9Score).reduce(0, +)) / Double(front9Rounds.count)
    }

    var avgBack9Score: Double? {
        guard !back9Rounds.isEmpty else { return nil }
        return Double(back9Rounds.map(\.back9Score).reduce(0, +)) / Double(back9Rounds.count)
    }

    var best18HoleScore: Int? { full18Rounds.map(\.totalScore).min() }

    var fairwayPct: Double {
        let possible = allScores.filter { $0.par != 3 }
        guard !possible.isEmpty else { return 0 }
        return Double(possible.filter(\.hitFairway).count) / Double(possible.count) * 100
    }

    var girPct: Double {
        guard !allScores.isEmpty else { return 0 }
        return Double(allScores.filter(\.hitGreen).count) / Double(allScores.count) * 100
    }

    var dropsPerRound: Double {
        guard !rounds.isEmpty else { return 0 }
        let total = allScores.filter { $0.teeResultRaw == "drop" }.count
        return Double(total) / Double(rounds.count)
    }

    var avgApproachDistance: Double {
        let withData = allScores.filter { $0.approachDistance > 0 }
        guard !withData.isEmpty else { return 0 }
        return Double(withData.map(\.approachDistance).reduce(0, +)) / Double(withData.count)
    }

    // MARK: - Short Game / Scrambling

    var scramblePct: Double {
        let missed = allScores.filter { !$0.hitGreen }
        guard !missed.isEmpty else { return 0 }
        let madeParOrBetter = missed.filter { $0.scoreToPar <= 0 }.count
        return Double(madeParOrBetter) / Double(missed.count) * 100
    }

    var multiChipPct: Double {
        let chipped = allScores.filter { !$0.hitGreen && !$0.chipClubRaw.isEmpty }
        guard !chipped.isEmpty else { return 0 }
        let multi = chipped.filter { $0.chipAttempts > 1 }.count
        return Double(multi) / Double(chipped.count) * 100
    }

    var avgChipAttempts: Double {
        let chipped = allScores.filter { !$0.hitGreen && !$0.chipClubRaw.isEmpty }
        guard !chipped.isEmpty else { return 0 }
        return Double(chipped.map(\.chipAttempts).reduce(0, +)) / Double(chipped.count)
    }

    struct ChipAttemptStat: Identifiable {
        var id: Int { attempts }
        let attempts: Int
        let count: Int
        let pct: Double
    }

    var chipAttemptBreakdown: [ChipAttemptStat] {
        let chipped = allScores.filter { !$0.hitGreen && !$0.chipClubRaw.isEmpty }
        guard !chipped.isEmpty else { return [] }
        let grouped = Dictionary(grouping: chipped) { $0.chipAttempts }
        let total = Double(chipped.count)
        return grouped.map { attempts, scores in
            ChipAttemptStat(attempts: attempts, count: scores.count, pct: Double(scores.count) / total * 100)
        }.sorted { $0.attempts < $1.attempts }
    }

    // MARK: - Scoring Distribution

    var eagleCount: Int { allScores.filter { $0.scoreToPar <= -2 }.count }
    var birdieCount: Int { allScores.filter { $0.scoreToPar == -1 }.count }
    var parCount: Int { allScores.filter { $0.scoreToPar == 0 }.count }
    var bogeyCount: Int { allScores.filter { $0.scoreToPar == 1 }.count }
    var doublePlusCount: Int { allScores.filter { $0.scoreToPar >= 2 }.count }

    var totalHolesPlayed: Int { allScores.count }

    func scorePct(_ count: Int) -> Double {
        guard totalHolesPlayed > 0 else { return 0 }
        return Double(count) / Double(totalHolesPlayed) * 100
    }

    // MARK: - Per-Hole Stats

    var holeCount: Int {
        let maxHole = allScores.map(\.holeNumber).max() ?? 18
        return max(maxHole, 1)
    }

    func holeStat(_ holeNumber: Int) -> HoleStat {
        let forHole = allScores.filter { $0.holeNumber == holeNumber }
        return HoleStat(holeNumber: holeNumber, scores: forHole)
    }

    var holeStats: [HoleStat] {
        (1...holeCount).map { holeStat($0) }
    }

    var heatMapOutlierThreshold: Double {
        let stats = holeStats.filter { $0.count > 0 }
        guard stats.count > 1 else { return 999 }
        let diffs = stats.map(\.avgScoreToPar)
        let mean = diffs.reduce(0, +) / Double(diffs.count)
        let variance = diffs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(diffs.count)
        return variance.squareRoot()
    }

    // MARK: - Approach by Distance

    static let distanceBuckets: [Int] = {
        var buckets = Array(stride(from: 20, through: 270, by: 10))
        buckets.append(275)
        return buckets
    }()

    var approachByDistance: [ApproachDistanceStat] {
        let withData = allScores.filter { $0.approachDistance > 0 }
        let grouped = Dictionary(grouping: withData) { $0.approachDistance }
        return Self.distanceBuckets.compactMap { bucket in
            guard let scores = grouped[bucket], !scores.isEmpty else { return nil }
            return ApproachDistanceStat(bucket: bucket, scores: scores)
        }
    }

    // MARK: - Score by Drink Progression

    struct DrinkProgressStat: Identifiable {
        var id: String { label }
        let label: String
        let minDrinks: Int
        let avgScoreToPar: Double
        let count: Int
    }

    var scoreByDrinkProgress: [DrinkProgressStat] {
        let boozingRounds = rounds.filter { $0.isBoozing || $0.totalDrinks > 0 }
        guard !boozingRounds.isEmpty else { return [] }

        var points: [(cumDrinks: Int, scoreToPar: Int)] = []
        for round in boozingRounds {
            var cumulative = 0
            for score in round.sortedScores {
                points.append((cumDrinks: cumulative, scoreToPar: score.scoreToPar))
                cumulative += score.drinksLogged
            }
        }

        let buckets: [(label: String, min: Int, max: Int)] = [
            ("0 drinks", 0, 0),
            ("1–2",       1, 2),
            ("3–4",       3, 4),
            ("5–6",       5, 6),
            ("7+",        7, 999),
        ]

        return buckets.compactMap { bucket in
            let filtered = points.filter { $0.cumDrinks >= bucket.min && $0.cumDrinks <= bucket.max }
            guard !filtered.isEmpty else { return nil }
            let avg = Double(filtered.map(\.scoreToPar).reduce(0, +)) / Double(filtered.count)
            return DrinkProgressStat(label: bucket.label, minDrinks: bucket.min, avgScoreToPar: avg, count: filtered.count)
        }
    }

    // MARK: - Factory

    static func filtered(rounds: [Round], tee: String?) -> StatsEngine {
        let filtered: [Round]
        if let tee = tee {
            filtered = rounds.filter { $0.teeRaw == tee }
        } else {
            filtered = rounds
        }
        return StatsEngine(rounds: filtered)
    }
}

// MARK: - Per-Hole Stat

struct HoleStat {
    let holeNumber: Int
    let scores: [HoleScore]

    var count: Int { scores.count }

    var holePar: Int {
        scores.first?.par ?? 4
    }

    var avgScore: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.map(\.score).reduce(0, +)) / Double(scores.count)
    }

    var avgScoreToPar: Double { avgScore - Double(holePar) }

    var bestScore: Int { scores.map(\.score).min() ?? 0 }
    var worstScore: Int { scores.map(\.score).max() ?? 0 }

    var avgPutts: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.map(\.putts).reduce(0, +)) / Double(scores.count)
    }

    var avgFirstPuttDist: Double {
        let withData = scores.filter { $0.firstPuttDistance > 0 }
        guard !withData.isEmpty else { return 0 }
        return Double(withData.map(\.firstPuttDistance).reduce(0, +)) / Double(withData.count)
    }

    var fairwayPct: Double {
        let possible = scores.filter { $0.par != 3 }
        guard !possible.isEmpty else { return 0 }
        return Double(possible.filter(\.hitFairway).count) / Double(possible.count) * 100
    }

    var girPct: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.filter(\.hitGreen).count) / Double(scores.count) * 100
    }

    var eagleCount: Int { scores.filter { $0.scoreToPar <= -2 }.count }
    var birdieCount: Int { scores.filter { $0.scoreToPar == -1 }.count }
    var parCountVal: Int { scores.filter { $0.scoreToPar == 0 }.count }
    var bogeyCount: Int { scores.filter { $0.scoreToPar == 1 }.count }
    var doublePlusCount: Int { scores.filter { $0.scoreToPar >= 2 }.count }

    var dropCount: Int { scores.filter { $0.teeResultRaw == "drop" }.count }
    var bunkerCount: Int {
        scores.filter { $0.teeResultRaw == "bunker" || $0.approachResultRaw == "bunker" }.count
    }
    var nativeCount: Int { scores.filter { $0.teeResultRaw == "native" }.count }

    var avgApproachDistance: Double {
        let withData = scores.filter { $0.approachDistance > 0 }
        guard !withData.isEmpty else { return 0 }
        return Double(withData.map(\.approachDistance).reduce(0, +)) / Double(withData.count)
    }

    func teeResultPct(_ result: String) -> Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.filter { $0.teeResultRaw == result }.count) / Double(scores.count) * 100
    }

    func approachResultPct(_ result: String) -> Double {
        let relevant = scores.filter { $0.par != 3 }
        guard !relevant.isEmpty else { return 0 }
        return Double(relevant.filter { $0.approachResultRaw == result }.count) / Double(relevant.count) * 100
    }

    // MARK: - Tee Club Breakdown

    struct TeeClubStat: Identifiable {
        var id: String { clubDisplayName }
        let clubDisplayName: String
        let count: Int
        let fairwayPct: Double   // par 4/5 only; -1 = not applicable (par 3)
        let girPct: Double       // par 3 only; -1 = not applicable
        let avgScore: Double
        let avgScoreToPar: Double
    }

    var byTeeClub: [TeeClubStat] {
        let withClub = scores.filter { !$0.teeClubRaw.isEmpty }
        guard !withClub.isEmpty else { return [] }
        let grouped = Dictionary(grouping: withClub) { $0.teeClubRaw }
        let par = holePar
        return grouped.compactMap { rawValue, clubScores in
            guard let club = Club(rawValue: rawValue) else { return nil }
            let fwyPossible = clubScores.filter { $0.par != 3 }
            let fwyPct = fwyPossible.isEmpty ? -1.0
                : Double(fwyPossible.filter { $0.teeResultRaw == "fairway" }.count) / Double(fwyPossible.count) * 100
            let girPossible = clubScores.filter { $0.par == 3 }
            let girPct = girPossible.isEmpty ? -1.0
                : Double(girPossible.filter { $0.teeResultRaw == "green" }.count) / Double(girPossible.count) * 100
            let avg = Double(clubScores.map(\.score).reduce(0, +)) / Double(clubScores.count)
            return TeeClubStat(
                clubDisplayName: club.displayName,
                count: clubScores.count,
                fairwayPct: fwyPct,
                girPct: girPct,
                avgScore: avg,
                avgScoreToPar: avg - Double(par)
            )
        }
        .filter { $0.count >= 1 }
        .sorted { $0.count > $1.count }
    }

    // MARK: - Tee Color Breakdown

    struct TeeColorStat: Identifiable {
        var id: String { teeName }
        let teeName: String
        let count: Int
        let avgScore: Double
        let avgScoreToPar: Double
    }

    var byTeeColor: [TeeColorStat] {
        let withTee = scores.filter { $0.round?.teeRaw != nil }
        guard !withTee.isEmpty else { return [] }
        let grouped = Dictionary(grouping: withTee) { $0.round?.teeRaw ?? "—" }
        let par = holePar
        return grouped.map { teeName, teeScores in
            let avg = Double(teeScores.map(\.score).reduce(0, +)) / Double(teeScores.count)
            return TeeColorStat(
                teeName: teeName,
                count: teeScores.count,
                avgScore: avg,
                avgScoreToPar: avg - Double(par)
            )
        }
        .sorted { $0.count > $1.count }
    }
}

// MARK: - Approach Distance Stat

struct ApproachDistanceStat: Identifiable {
    var id: Int { bucket }
    let bucket: Int
    let scores: [HoleScore]

    var label: String { bucket == 275 ? "275+" : "\(bucket) yds" }
    var count: Int { scores.count }

    var greenPct: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.filter(\.hitGreen).count) / Double(scores.count) * 100
    }

    func resultPct(_ result: String) -> Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.filter { $0.approachResultRaw == result }.count) / Double(scores.count) * 100
    }

    var greenCount: Int { scores.filter(\.hitGreen).count }
    var shortCount: Int { scores.filter { $0.approachResultRaw == "short" }.count }
    var longCount: Int { scores.filter { $0.approachResultRaw == "long" }.count }
    var leftCount: Int { scores.filter { $0.approachResultRaw == "left" }.count }
    var rightCount: Int { scores.filter { $0.approachResultRaw == "right" }.count }
    var bunkerCount: Int { scores.filter { $0.approachResultRaw == "bunker" }.count }
}
