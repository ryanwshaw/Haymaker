import Foundation
import SwiftData

@Model
final class Round {
    var date: Date
    var notes: String
    var isComplete: Bool
    var teeRaw: String

    @Relationship(deleteRule: .cascade, inverse: \HoleScore.round)
    var scores: [HoleScore] = []

    init(date: Date = .now, notes: String = "", isComplete: Bool = false, tee: Tee = .white) {
        self.date = date
        self.notes = notes
        self.isComplete = isComplete
        self.teeRaw = tee.rawValue
    }

    var tee: Tee {
        get { Tee(rawValue: teeRaw) ?? .white }
        set { teeRaw = newValue.rawValue }
    }

    var sortedScores: [HoleScore] {
        scores.sorted { $0.holeNumber < $1.holeNumber }
    }

    var totalScore: Int { scores.map(\.score).reduce(0, +) }
    var totalPutts: Int { scores.map(\.putts).reduce(0, +) }
    var totalPar: Int { 72 }
    var scoreToPar: Int { totalScore - totalPar }

    var scoreToParString: String {
        let diff = scoreToPar
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    var fairwaysHit: Int {
        scores.filter { $0.par != 3 && $0.hitFairway }.count
    }

    var fairwaysPossible: Int {
        scores.filter { $0.par != 3 }.count
    }

    var fairwayPct: Double {
        guard fairwaysPossible > 0 else { return 0 }
        return Double(fairwaysHit) / Double(fairwaysPossible) * 100
    }

    var girCount: Int { scores.filter(\.hitGreen).count }

    var girPct: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(girCount) / Double(scores.count) * 100
    }
}
