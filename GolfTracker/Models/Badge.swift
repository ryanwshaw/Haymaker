import Foundation

enum BadgeType: String, Codable, CaseIterable, Identifiable {
    case doubleKill
    case shaiHulud

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .doubleKill: return "DOUBLE KILL"
        case .shaiHulud: return "SHAI-HULUD"
        }
    }

    var subtitle: String {
        switch self {
        case .doubleKill: return "2 birdies in a row"
        case .shaiHulud: return "Up & down from a greenside bunker"
        }
    }

    var imageName: String {
        switch self {
        case .doubleKill: return "BadgeDoubleKill"
        case .shaiHulud: return "BadgeShaiHulud"
        }
    }

    var isCircularImage: Bool {
        switch self {
        case .doubleKill: return false
        case .shaiHulud: return true
        }
    }
}

struct EarnedBadge: Codable, Identifiable {
    var id: String { "\(type.rawValue)-\(earnedAt.timeIntervalSince1970)" }
    let type: BadgeType
    let earnedAt: Date
    let roundDate: Date?
    let courseName: String?
    let holeNumbers: [Int]
}

// MARK: - Badge Manager

final class BadgeManager: ObservableObject {
    static let shared = BadgeManager()

    @Published var earnedBadges: [EarnedBadge] = []
    @Published var pendingBadge: BadgeType? = nil

    /// Tracks badges already awarded this session to prevent duplicates.
    /// Key format: "badgeType-hole1-hole2-..." per round.
    private var sessionAwarded: Set<String> = []

    private let storageKey = "earnedBadges"

    private init() {
        load()
    }

    var badgeCounts: [BadgeType: Int] {
        var counts: [BadgeType: Int] = [:]
        for badge in earnedBadges {
            counts[badge.type, default: 0] += 1
        }
        return counts
    }

    func count(for type: BadgeType) -> Int {
        earnedBadges.filter { $0.type == type }.count
    }

    func resetSession() {
        sessionAwarded.removeAll()
    }

    private func sessionKey(_ type: BadgeType, holes: [Int]) -> String {
        "\(type.rawValue)-\(holes.map(String.init).joined(separator: ","))"
    }

    func award(_ type: BadgeType, roundDate: Date?, courseName: String?, holeNumbers: [Int]) {
        let key = sessionKey(type, holes: holeNumbers)
        guard !sessionAwarded.contains(key) else { return }
        sessionAwarded.insert(key)

        let badge = EarnedBadge(
            type: type,
            earnedAt: .now,
            roundDate: roundDate,
            courseName: courseName,
            holeNumbers: holeNumbers
        )
        earnedBadges.append(badge)
        save()

        if pendingBadge == nil {
            pendingBadge = type
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                self.pendingBadge = type
            }
        }
    }

    func clearPending() {
        pendingBadge = nil
    }

    // MARK: - Detection

    func checkForBadges(score: HoleScore, allScores: [HoleScore], currentIndex: Int, round: Round) {
        guard !score.teeResultRaw.isEmpty else { return }

        checkDoubleKill(current: score, allScores: allScores, currentIndex: currentIndex, round: round)
        checkShaiHulud(score: score, round: round)
    }

    private func checkDoubleKill(current: HoleScore, allScores: [HoleScore], currentIndex: Int, round: Round) {
        guard currentIndex > 0 else { return }
        let previous = allScores[currentIndex - 1]

        guard !current.teeResultRaw.isEmpty, !previous.teeResultRaw.isEmpty else { return }
        guard current.scoreToPar <= -1 && previous.scoreToPar <= -1 else { return }

        award(.doubleKill,
              roundDate: round.date,
              courseName: round.courseName,
              holeNumbers: [previous.holeNumber, current.holeNumber])
    }

    private func checkShaiHulud(score: HoleScore, round: Round) {
        let wasInGreensideBunker: Bool
        if score.par == 3 {
            wasInGreensideBunker = score.teeResultRaw == "bunker"
        } else {
            wasInGreensideBunker = score.approachResultRaw == "bunker"
        }

        guard wasInGreensideBunker, score.putts == 1 else { return }

        award(.shaiHulud,
              roundDate: round.date,
              courseName: round.courseName,
              holeNumbers: [score.holeNumber])
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(earnedBadges) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let badges = try? JSONDecoder().decode([EarnedBadge].self, from: data) else { return }
        earnedBadges = badges
    }
}
