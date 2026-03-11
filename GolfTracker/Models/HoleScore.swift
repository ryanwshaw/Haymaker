import Foundation
import SwiftData

@Model
final class HoleScore {
    var holeNumber: Int
    var score: Int
    var putts: Int

    // Step 1: Tee shot result
    // Par 4/5: "fairway", "rough_left", "rough_right", "native", "bunker", "drop"
    // Par 3: "green", "short", "long", "left", "right", "bunker"
    var teeResultRaw: String
    var teeClubRaw: String

    // Step 2: Distance remaining (par 4/5 only)
    var approachDistance: Int

    // Step 3: Approach result (par 4/5)
    // "green", "short", "long", "left", "right", "bunker"
    var approachResultRaw: String
    var approachClubRaw: String

    // Step 4: Short game (if missed green)
    var chipClubRaw: String

    // Step 5: Putts (already have putts field above)
    var firstPuttDistance: Int

    // Trouble / extra
    var greensideBunker: Bool
    var penalties: Int

    var round: Round?

    init(
        holeNumber: Int,
        score: Int = 0,
        putts: Int = 2,
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

    var holeInfo: HoleInfo { Haymaker.hole(holeNumber) }
    var par: Int { holeInfo.par }
    var scoreToPar: Int { score - par }

    var hitFairway: Bool { teeResultRaw == "fairway" }
    var hitGreen: Bool {
        if par == 3 { return teeResultRaw == "green" }
        return approachResultRaw == "green"
    }

    func yardage(for tee: Tee) -> Int {
        holeInfo.yardage(for: tee)
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
