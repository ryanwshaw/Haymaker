import SwiftUI

enum Tee: String, CaseIterable, Codable {
    case silver = "Silver"
    case gold = "Gold"
    case white = "White"
    case blue = "Blue"
    case family = "Family"

    var color: Color {
        switch self {
        case .silver: return Color(.systemGray)
        case .gold: return Color(.systemYellow)
        case .white: return Color(.label)
        case .blue: return Color(.systemBlue)
        case .family: return Color(.systemRed)
        }
    }

    var totalYardage: Int {
        Haymaker.holes.compactMap { $0.yardages[self] }.reduce(0, +)
    }

    var rating: String {
        switch self {
        case .silver: return "73.3/140"
        case .gold: return "70.1/131"
        case .white: return "67.3/123"
        case .blue: return "62.2/103"
        case .family: return "—"
        }
    }
}
