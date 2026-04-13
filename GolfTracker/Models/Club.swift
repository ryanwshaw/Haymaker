import Foundation

enum Club: String, CaseIterable, Codable {
    case driver = "Driver"
    case drivingIron = "Driving Iron"
    case threeWood = "3 Wood"
    case fiveWood = "5 Wood"
    case sevenWood = "7 Wood"
    case twoHybrid = "2 Hybrid"
    case threeHybrid = "3 Hybrid"
    case fourHybrid = "4 Hybrid"
    case fiveHybrid = "5 Hybrid"
    case hybrid = "Hybrid"
    case threeIron = "3 Iron"
    case fourIron = "4 Iron"
    case fiveIron = "5 Iron"
    case sixIron = "6 Iron"
    case sevenIron = "7 Iron"
    case eightIron = "8 Iron"
    case nineIron = "9 Iron"
    case pitchingWedge = "PW"
    case gapWedge = "GW"
    case sandWedge = "SW"
    case lobWedge = "LW"
    case putter = "Putter"

    var displayName: String { rawValue }

    static var teeClubs: [Club] {
        allCases.filter { $0 != .putter }
    }

    static var approachClubs: [Club] {
        allCases.filter { $0 != .driver && $0 != .putter }
    }

    /// Fuzzy-match a club name string (from a CSV) to a Club enum case.
    /// Handles common launch monitor naming: "7 Iron", "7i", "7-Iron", "7I", "3W", "3 Wood", "PW", etc.
    static func fuzzyMatch(_ input: String) -> Club? {
        let s = input.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        let map: [(keywords: [String], club: Club)] = [
            (["driver", "dr", "1w", "1 wood"], .driver),
            (["driving iron", "di", "1i", "1 iron"], .drivingIron),
            (["3 wood", "3w", "three wood", "3wood"], .threeWood),
            (["5 wood", "5w", "five wood", "5wood"], .fiveWood),
            (["7 wood", "7w", "seven wood", "7wood"], .sevenWood),
            (["2 hybrid", "2h", "2hybrid"], .twoHybrid),
            (["3 hybrid", "3h", "3hybrid"], .threeHybrid),
            (["4 hybrid", "4h", "4hybrid"], .fourHybrid),
            (["5 hybrid", "5h", "5hybrid"], .fiveHybrid),
            (["hybrid"], .hybrid),
            (["2 iron", "2i", "2iron"], .drivingIron),
            (["3 iron", "3i", "3iron"], .threeIron),
            (["4 iron", "4i", "4iron"], .fourIron),
            (["5 iron", "5i", "5iron"], .fiveIron),
            (["6 iron", "6i", "6iron"], .sixIron),
            (["7 iron", "7i", "7iron"], .sevenIron),
            (["8 iron", "8i", "8iron"], .eightIron),
            (["9 iron", "9i", "9iron"], .nineIron),
            (["pitching wedge", "pw", "pitching"], .pitchingWedge),
            (["gap wedge", "gw", "gap", "aw", "approach wedge"], .gapWedge),
            (["sand wedge", "sw", "sand"], .sandWedge),
            (["lob wedge", "lw", "lob"], .lobWedge),
            (["putter", "pt"], .putter),
        ]

        // Exact-ish check first: does the normalized input match a keyword exactly?
        for entry in map {
            if entry.keywords.contains(s) { return entry.club }
        }
        // Substring: does the input contain one of the keywords?
        for entry in map {
            for kw in entry.keywords where s.contains(kw) {
                return entry.club
            }
        }
        // Try matching the raw value directly
        for club in Club.allCases {
            if club.rawValue.lowercased() == s { return club }
        }
        return nil
    }
}

// MARK: - Bag Manager

class BagManager: ObservableObject {
    static let shared = BagManager()

    private static let storageKey = "myBagClubs"
    private static let yardageKey = "clubYardages"

    @Published var clubs: [Club] {
        didSet { saveClubs() }
    }

    /// Average carry yardage per club, set by the user.
    @Published var clubYardages: [Club: Int] {
        didSet { saveYardages() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([Club].self, from: data) {
            self.clubs = saved
        } else {
            self.clubs = Club.allCases
        }

        if let data = UserDefaults.standard.data(forKey: Self.yardageKey),
           let saved = try? JSONDecoder().decode([Club: Int].self, from: data) {
            self.clubYardages = saved
        } else {
            self.clubYardages = [:]
        }
    }

    private func saveClubs() {
        if let data = try? JSONEncoder().encode(clubs) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func saveYardages() {
        if let data = try? JSONEncoder().encode(clubYardages) {
            UserDefaults.standard.set(data, forKey: Self.yardageKey)
        }
    }

    private var hasAnyYardages: Bool {
        !clubYardages.isEmpty
    }

    var teeClubs: [Club] {
        let base = clubs.filter { $0 != .putter }
        guard hasAnyYardages else { return base }
        return base.filter { clubYardages[$0] != nil }
    }

    var approachClubs: [Club] {
        let base = clubs.filter { $0 != .driver && $0 != .putter }
        guard hasAnyYardages else { return base }
        return base.filter { clubYardages[$0] != nil }
    }

    func toggle(_ club: Club) {
        if clubs.contains(club) {
            clubs.removeAll { $0 == club }
        } else {
            clubs.append(club)
            clubs.sort { Club.allCases.firstIndex(of: $0)! < Club.allCases.firstIndex(of: $1)! }
        }
    }

    // MARK: - CSV Import

    /// Parses a launch monitor CSV, matches club names to enum cases,
    /// adds them to the bag, and sets average carry yardage. Returns count of clubs imported.
    func importFromCSV(_ csvText: String) -> Int {
        let lines = csvText.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        guard lines.count >= 2 else { return 0 }

        let headers = lines[0].lowercased()
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "") }

        let clubIdx = headers.firstIndex(where: { $0.contains("club") || $0.contains("name") })
        let carryIdx = headers.firstIndex(where: { $0.contains("carry") })
        let totalIdx = headers.firstIndex(where: { $0.contains("total") || $0.contains("distance") })

        guard let ci = clubIdx, (carryIdx != nil || totalIdx != nil) else { return 0 }

        var clubData: [String: [Double]] = [:]
        for i in 1..<lines.count {
            let cols = lines[i].components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
            }
            guard ci < cols.count else { continue }
            let name = cols[ci]
            guard !name.isEmpty else { continue }

            let yardage: Double?
            if let cIdx = carryIdx, cIdx < cols.count, let val = Double(cols[cIdx]), val > 0 {
                yardage = val
            } else if let tIdx = totalIdx, tIdx < cols.count, let val = Double(cols[tIdx]), val > 0 {
                yardage = val
            } else {
                yardage = nil
            }
            guard let yds = yardage else { continue }
            clubData[name, default: []].append(yds)
        }

        var importedCount = 0
        for (name, distances) in clubData {
            guard let club = Club.fuzzyMatch(name) else { continue }
            let avg = Int(distances.reduce(0, +) / Double(distances.count))
            guard avg > 0 else { continue }

            if !clubs.contains(club) {
                clubs.append(club)
            }
            clubYardages[club] = avg
            importedCount += 1
        }

        if importedCount > 0 {
            clubs.sort { Club.allCases.firstIndex(of: $0)! < Club.allCases.firstIndex(of: $1)! }
        }
        return importedCount
    }

    /// Returns the club whose average yardage is closest to the target distance.
    /// Only considers clubs in the bag with a yardage set.
    func bestClub(for distance: Int, from pool: [Club]) -> Club? {
        guard distance > 0 else { return nil }
        var best: Club?
        var bestDelta = Int.max
        for club in pool {
            guard let yds = clubYardages[club] else { continue }
            let delta = abs(yds - distance)
            if delta < bestDelta {
                bestDelta = delta
                best = club
            }
        }
        return best
    }
}
