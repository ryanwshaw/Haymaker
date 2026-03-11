import SwiftUI

/// Legacy tee enum — kept for backward compatibility with existing data.
/// New code should use CourseTeeInfo from the Course model.
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

/// Resolves a tee name to a display color, checking CourseTeeInfo first then legacy Tee enum.
func teeColor(for name: String, in course: Course?) -> Color {
    if let info = course?.teeInfo(named: name) {
        return info.color
    }
    if let legacy = Tee(rawValue: name) {
        return legacy.color
    }
    return Color(.systemGray)
}
