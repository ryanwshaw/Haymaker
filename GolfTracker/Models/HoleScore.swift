import Foundation
import SwiftData

@Model
final class HoleScore {
    var holeNumber: Int
    var score: Int
    var putts: Int

    // Stored hole metadata (set at round creation from course data)
    var holePar: Int
    var holeName: String
    var holeYardage: Int
    var holeMensHdcp: Int

    // Step 1: Tee shot result
    var teeResultRaw: String
    var teeClubRaw: String

    // Step 2: Distance remaining (par 4/5 only)
    var approachDistance: Int

    // Step 3: Approach result (par 4/5)
    var approachResultRaw: String
    var approachClubRaw: String

    // Step 4: Short game (if missed green)
    var chipClubRaw: String

    // Step 5: Putts
    var firstPuttDistance: Int

    // Trouble / extra
    var greensideBunker: Bool
    var penalties: Int

    var round: Round?

    init(
        holeNumber: Int,
        score: Int = 0,
        putts: Int = 2,
        holePar: Int = 4,
        holeName: String = "",
        holeYardage: Int = 0,
        holeMensHdcp: Int = 0,
        teeResultRaw: String = "",
        teeClubRaw: String = "",
        approachDistance: Int = 0,
        approachResultRaw: String = "",
        approachClubRaw: String = "",
        chipClubRaw: String = "",
        firstPuttDistance: Int = 0,
        greensideBunker: Bool = false,
        penalties: Int = 0
    ) {
        self.holeNumber = holeNumber
        self.score = score
        self.putts = putts
        self.holePar = holePar
        self.holeName = holeName
        self.holeYardage = holeYardage
        self.holeMensHdcp = holeMensHdcp
        self.teeResultRaw = teeResultRaw
        self.teeClubRaw = teeClubRaw
        self.approachDistance = approachDistance
        self.approachResultRaw = approachResultRaw
        self.approachClubRaw = approachClubRaw
        self.chipClubRaw = chipClubRaw
        self.firstPuttDistance = firstPuttDistance
        self.greensideBunker = greensideBunker
        self.penalties = penalties
    }

    var teeClub: Club? {
        get { Club(rawValue: teeClubRaw) }
        set { teeClubRaw = newValue?.rawValue ?? "" }
    }

    var approachClub: Club? {
        get { Club(rawValue: approachClubRaw) }
        set { approachClubRaw = newValue?.rawValue ?? "" }
    }

    var chipClub: Club? {
        get { Club(rawValue: chipClubRaw) }
        set { chipClubRaw = newValue?.rawValue ?? "" }
    }

    /// Par for this hole. Uses stored value; falls back to Haymaker for legacy data.
    var par: Int {
        if holePar > 0 { return holePar }
        if holeNumber >= 1 && holeNumber <= 18 {
            return Haymaker.hole(holeNumber).par
        }
        return 4
    }

    var scoreToPar: Int { score - par }

    /// Builds a HoleInfo from stored metadata or falls back to Haymaker for legacy rounds.
    var holeInfo: HoleInfo {
        if !holeName.isEmpty {
            return HoleInfo(
                number: holeNumber,
                name: holeName,
                par: par,
                mensHdcp: holeMensHdcp,
                ladiesHdcp: 0,
                yardages: [:]
            )
        }
        if holeNumber >= 1 && holeNumber <= 18 {
            return Haymaker.hole(holeNumber)
        }
        return HoleInfo(number: holeNumber, name: "Hole \(holeNumber)", par: par,
                        mensHdcp: 0, ladiesHdcp: 0, yardages: [:])
    }

    /// Full hole info from the round's course, with fallback.
    func courseHoleInfo() -> HoleInfo {
        if let courseHole = round?.course?.hole(holeNumber) {
            return courseHole.toHoleInfo()
        }
        return holeInfo
    }

    var hitFairway: Bool { teeResultRaw == "fairway" }
    var hitGreen: Bool {
        if par == 3 { return teeResultRaw == "green" }
        return approachResultRaw == "green"
    }

    func yardage(for teeName: String) -> Int {
        if let courseHole = round?.course?.hole(holeNumber) {
            return courseHole.yardage(for: teeName)
        }
        return holeInfo.yardage(for: teeName)
    }

    var scoreLabel: String {
        let diff = scoreToPar
        switch diff {
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double"
        default:
            return diff < 0 ? "\(abs(diff)) under" : "+\(diff)"
        }
    }
}
