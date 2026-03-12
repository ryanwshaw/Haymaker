import CloudKit
import Foundation

struct SharedHoleScore {
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

struct SharedRoundSummary: Identifiable {
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

    static func from(_ record: CKRecord) -> SharedRoundSummary {
        var holeScores: [SharedHoleScore] = []
        if let json = record["holeScoresJSON"] as? String,
           let data = json.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            holeScores = array.map { dict in
                SharedHoleScore(
                    holeNumber: dict["hole"] as? Int ?? 0,
                    score: dict["score"] as? Int ?? 0,
                    par: dict["par"] as? Int ?? 4,
                    putts: dict["putts"] as? Int ?? 0,
                    teeResult: dict["teeResult"] as? String ?? "",
                    approachResult: dict["approachResult"] as? String ?? "",
                    approachDistance: dict["approachDistance"] as? Int ?? 0,
                    hitFairway: dict["hitFairway"] as? Bool ?? false,
                    hitGreen: dict["hitGreen"] as? Bool ?? false
                )
            }
        }

        return SharedRoundSummary(
            id: record.recordID.recordName,
            courseName: record["courseName"] as? String ?? "",
            tee: record["tee"] as? String ?? "",
            date: record["date"] as? Date ?? Date(),
            totalScore: record["totalScore"] as? Int ?? 0,
            scoreToPar: record["scoreToPar"] as? Int ?? 0,
            holesPlayed: record["holesPlayed"] as? Int ?? 0,
            totalPutts: record["totalPutts"] as? Int ?? 0,
            fairwayPct: record["fairwayPct"] as? Double ?? 0,
            girPct: record["girPct"] as? Double ?? 0,
            front9Score: record["front9Score"] as? Int ?? 0,
            back9Score: record["back9Score"] as? Int ?? 0,
            hasFull18: (record["hasFull18"] as? Int ?? 0) == 1,
            hasFront9: (record["hasFront9"] as? Int ?? 0) == 1,
            hasBack9: (record["hasBack9"] as? Int ?? 0) == 1,
            holeScores: holeScores
        )
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
