import Foundation

// MARK: - Local Friend (for mock/offline friends)

struct LocalFriend: Identifiable, Codable {
    let id: String
    let name: String
    let code: String
}


struct SharedHoleScore: Codable {
    let holeNumber: Int
    let score: Int
    let par: Int
    let putts: Int
    let teeResult: String
    let approachResult: String
    let approachDistance: Int
    let hitFairway: Bool
    let hitGreen: Bool

    var scoreToPar: Int { score - par }
}

struct SharedRoundSummary: Identifiable, Codable {
    let id: String
    let courseName: String
    let tee: String
    let date: Date
    let totalScore: Int
    let scoreToPar: Int
    let holesPlayed: Int
    let totalPutts: Int
    let fairwayPct: Double
    let girPct: Double
    let front9Score: Int
    let back9Score: Int
    let hasFull18: Bool
    let hasFront9: Bool
    let hasBack9: Bool
    let holeScores: [SharedHoleScore]

    var scoreToParString: String {
        if scoreToPar == 0 { return "E" }
        return scoreToPar > 0 ? "+\(scoreToPar)" : "\(scoreToPar)"
    }

    var totalPar: Int {
        holeScores.map(\.par).reduce(0, +)
    }

    /// Convert a local Round to SharedRoundSummary for use in comparison stats.
    static func from(_ round: Round) -> SharedRoundSummary {
        SharedRoundSummary(
            id: round.date.ISO8601Format(),
            courseName: round.courseName,
            tee: round.teeRaw,
            date: round.date,
            totalScore: round.totalScore,
            scoreToPar: round.scoreToPar,
            holesPlayed: round.holesPlayed,
            totalPutts: round.totalPutts,
            fairwayPct: round.fairwayPct,
            girPct: round.girPct,
            front9Score: round.front9Score,
            back9Score: round.back9Score,
            hasFull18: round.hasFull18,
            hasFront9: round.hasFront9,
            hasBack9: round.hasBack9,
            holeScores: round.sortedScores.map { score in
                SharedHoleScore(
                    holeNumber: score.holeNumber,
                    score: score.score,
                    par: score.par,
                    putts: score.putts,
                    teeResult: score.teeResultRaw,
                    approachResult: score.approachResultRaw,
                    approachDistance: score.approachDistance,
                    hitFairway: score.hitFairway,
                    hitGreen: score.hitGreen
                )
            }
        )
    }
}
