import Foundation

struct FriendStatsEngine {
    let rounds: [SharedRoundSummary]

    var allScores: [SharedHoleScore] {
        rounds.flatMap(\.holeScores)
    }

    var roundCount: Int { rounds.count }

    // MARK: - Scoring Averages

    private var full18Rounds: [SharedRoundSummary] { rounds.filter(\.hasFull18) }
    private var front9Rounds: [SharedRoundSummary] { rounds.filter(\.hasFront9) }
    private var back9Rounds: [SharedRoundSummary] { rounds.filter(\.hasBack9) }

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
        let total = allScores.filter { $0.teeResult == "drop" }.count
        return Double(total) / Double(rounds.count)
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

    // MARK: - Per-Hole

    var holeCount: Int {
        let maxHole = allScores.map(\.holeNumber).max() ?? 18
        return max(maxHole, 1)
    }

    func holeStat(_ holeNumber: Int) -> FriendHoleStat {
        let forHole = allScores.filter { $0.holeNumber == holeNumber }
        return FriendHoleStat(holeNumber: holeNumber, scores: forHole)
    }

    var holeStats: [FriendHoleStat] {
        guard holeCount >= 1 else { return [] }
        return (1...holeCount).map { holeStat($0) }
    }

    // MARK: - Par-Type Averages (for insights)

    var avgScoreOnPar3s: Double {
        let par3s = allScores.filter { $0.par == 3 }
        guard !par3s.isEmpty else { return 0 }
        return Double(par3s.map(\.score).reduce(0, +)) / Double(par3s.count)
    }

    var avgScoreOnPar4s: Double {
        let par4s = allScores.filter { $0.par == 4 }
        guard !par4s.isEmpty else { return 0 }
        return Double(par4s.map(\.score).reduce(0, +)) / Double(par4s.count)
    }

    var avgScoreOnPar5s: Double {
        let par5s = allScores.filter { $0.par == 5 }
        guard !par5s.isEmpty else { return 0 }
        return Double(par5s.map(\.score).reduce(0, +)) / Double(par5s.count)
    }

    // MARK: - Filtered Factory

    static func filtered(rounds: [SharedRoundSummary], tee: String?) -> FriendStatsEngine {
        let filtered: [SharedRoundSummary]
        if let tee = tee {
            filtered = rounds.filter { $0.tee == tee }
        } else {
            filtered = rounds
        }
        return FriendStatsEngine(rounds: filtered)
    }
}

struct FriendHoleStat {
    let holeNumber: Int
    let scores: [SharedHoleScore]

    var count: Int { scores.count }
    var holePar: Int { scores.first?.par ?? 4 }

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

    var fairwayPct: Double {
        let possible = scores.filter { $0.par != 3 }
        guard !possible.isEmpty else { return 0 }
        return Double(possible.filter(\.hitFairway).count) / Double(possible.count) * 100
    }

    var girPct: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.filter(\.hitGreen).count) / Double(scores.count) * 100
    }
}
