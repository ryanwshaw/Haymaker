import Foundation

struct StatsEngine {
    let rounds: [Round]

    var allScores: [HoleScore] {
        rounds.flatMap(\.sortedScores)
    }

    // MARK: - Overall

    var roundCount: Int { rounds.count }

    var avgScore: Double {
        guard !rounds.isEmpty else { return 0 }
        return Double(rounds.map(\.totalScore).reduce(0, +)) / Double(rounds.count)
    }

    var avgPutts: Double {
        guard !rounds.isEmpty else { return 0 }
        return Double(rounds.map(\.totalPutts).reduce(0, +)) / Double(rounds.count)
    }

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

    func holeStat(_ holeNumber: Int) -> HoleStat {
        let forHole = allScores.filter { $0.holeNumber == holeNumber }
        return HoleStat(holeNumber: holeNumber, scores: forHole)
    }

    var holeStats: [HoleStat] {
        (1...18).map { holeStat($0) }
    }

    var heatMapOutlierThreshold: Double {
        let stats = holeStats.filter { $0.count > 0 }
        guard stats.count > 1 else { return 999 }
        let diffs = stats.map(\.avgScoreToPar)
        let mean = diffs.reduce(0, +) / Double(diffs.count)
        let variance = diffs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(diffs.count)
        return variance.squareRoot()
    }

    // MARK: - Club Distances

    var clubDistances: [ClubDistanceStat] {
        let withData = allScores.filter { !$0.approachClubRaw.isEmpty && $0.approachDistance > 0 }
        let grouped = Dictionary(grouping: withData) { $0.approachClubRaw }
        return grouped.map { club, scores in
            let total = scores.map(\.approachDistance).reduce(0, +)
            return ClubDistanceStat(club: club, avgYards: total / scores.count, count: scores.count)
        }
        .sorted { $0.avgYards > $1.avgYards }
    }

    // MARK: - Factory

    static func filtered(rounds: [Round], tee: Tee?) -> StatsEngine {
        let filtered: [Round]
        if let tee = tee {
            filtered = rounds.filter { $0.tee == tee }
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

    var info: HoleInfo { Haymaker.hole(holeNumber) }
    var count: Int { scores.count }

    var avgScore: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.map(\.score).reduce(0, +)) / Double(scores.count)
    }

    var avgScoreToPar: Double { avgScore - Double(info.par) }

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

    // Tee result distribution (for par 4/5)
    func teeResultPct(_ result: String) -> Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.filter { $0.teeResultRaw == result }.count) / Double(scores.count) * 100
    }

    // Approach result distribution (for par 4/5)
    func approachResultPct(_ result: String) -> Double {
        let relevant = scores.filter { $0.par != 3 }
        guard !relevant.isEmpty else { return 0 }
        return Double(relevant.filter { $0.approachResultRaw == result }.count) / Double(relevant.count) * 100
    }
}

// MARK: - Club Distance Stat

struct ClubDistanceStat: Identifiable {
    var id: String { club }
    let club: String
    let avgYards: Int
    let count: Int
}
