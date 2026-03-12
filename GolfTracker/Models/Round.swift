import Foundation
import SwiftUI
import SwiftData

@Model
final class Round {
    var date: Date
    var notes: String
    var isComplete: Bool
    var teeRaw: String
    var course: Course?

    @Relationship(deleteRule: .cascade, inverse: \HoleScore.round)
    var scores: [HoleScore] = []

    init(date: Date = .now, notes: String = "", isComplete: Bool = false, tee: String = "White", course: Course? = nil) {
        self.date = date
        self.notes = notes
        self.isComplete = isComplete
        self.teeRaw = tee
        self.course = course
    }

    var sortedScores: [HoleScore] {
        scores.sorted { $0.holeNumber < $1.holeNumber }
    }

    var totalScore: Int { scores.map(\.score).reduce(0, +) }
    var totalPutts: Int { scores.map(\.putts).reduce(0, +) }

    var totalPar: Int {
        let fromScores = scores.map(\.par).reduce(0, +)
        if fromScores > 0 { return fromScores }
        return course?.totalPar ?? 72
    }

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

    var holesPlayed: Int { scores.count }

    var hasFront9: Bool {
        let front = scores.filter { $0.holeNumber >= 1 && $0.holeNumber <= 9 }
        return front.count == 9
    }

    var hasBack9: Bool {
        let back = scores.filter { $0.holeNumber >= 10 && $0.holeNumber <= 18 }
        return back.count == 9
    }

    var hasFull18: Bool { hasFront9 && hasBack9 }

    var front9Score: Int {
        scores.filter { $0.holeNumber >= 1 && $0.holeNumber <= 9 }.map(\.score).reduce(0, +)
    }

    var back9Score: Int {
        scores.filter { $0.holeNumber >= 10 && $0.holeNumber <= 18 }.map(\.score).reduce(0, +)
    }

    var front9Par: Int {
        scores.filter { $0.holeNumber >= 1 && $0.holeNumber <= 9 }.map(\.par).reduce(0, +)
    }

    var back9Par: Int {
        scores.filter { $0.holeNumber >= 10 && $0.holeNumber <= 18 }.map(\.par).reduce(0, +)
    }

    var displayTeeColor: Color {
        GolfTracker.teeColor(for: teeRaw, in: course)
    }

    var courseName: String {
        course?.name ?? "Haymaker"
    }
}
