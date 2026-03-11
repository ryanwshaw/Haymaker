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
}

// MARK: - Bag Manager

class BagManager: ObservableObject {
    static let shared = BagManager()

    private static let storageKey = "myBagClubs"

    @Published var clubs: [Club] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([Club].self, from: data) {
            self.clubs = saved
        } else {
            self.clubs = Club.allCases
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(clubs) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    var teeClubs: [Club] {
        clubs.filter { $0 != .putter }
    }

    var approachClubs: [Club] {
        clubs.filter { $0 != .driver && $0 != .putter }
    }

    func toggle(_ club: Club) {
        if clubs.contains(club) {
            clubs.removeAll { $0 == club }
        } else {
            var all = Club.allCases
            clubs.append(club)
            clubs.sort { all.firstIndex(of: $0)! < all.firstIndex(of: $1)! }
        }
    }
}
