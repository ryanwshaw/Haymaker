import Foundation
import SwiftData
import SwiftUI

// MARK: - Tee metadata (not a SwiftData model — stored as JSON on Course)

struct CourseTeeInfo: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var colorHex: String
    var rating: String
    var sortOrder: Int

    var color: Color {
        Color(hex: colorHex)
    }

    static let defaultTees: [CourseTeeInfo] = [
        CourseTeeInfo(name: "Black", colorHex: "1C1C1E", rating: "—", sortOrder: 0),
        CourseTeeInfo(name: "Blue", colorHex: "007AFF", rating: "—", sortOrder: 1),
        CourseTeeInfo(name: "White", colorHex: "8E8E93", rating: "—", sortOrder: 2),
        CourseTeeInfo(name: "Gold", colorHex: "FFD60A", rating: "—", sortOrder: 3),
        CourseTeeInfo(name: "Red", colorHex: "FF3B30", rating: "—", sortOrder: 4),
    ]
}

// MARK: - Course

@Model
final class Course {
    var name: String
    var logoData: Data?
    var photoData: Data?
    var scorecardImageData: Data?
    var teesData: Data
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CourseHole.course)
    var holes: [CourseHole] = []

    init(name: String, tees: [CourseTeeInfo] = [], logoData: Data? = nil) {
        self.name = name
        self.logoData = logoData
        self.photoData = nil
        self.scorecardImageData = nil
        self.teesData = (try? JSONEncoder().encode(tees)) ?? Data()
        self.createdAt = .now
    }

    var teeInfos: [CourseTeeInfo] {
        get {
            (try? JSONDecoder().decode([CourseTeeInfo].self, from: teesData)) ?? []
        }
        set {
            teesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var sortedHoles: [CourseHole] {
        holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    var totalPar: Int {
        holes.map(\.par).reduce(0, +)
    }

    func totalYardage(for teeName: String) -> Int {
        holes.compactMap { $0.yardage(for: teeName) }.reduce(0, +)
    }

    func hole(_ number: Int) -> CourseHole? {
        holes.first { $0.holeNumber == number }
    }

    func teeInfo(named name: String) -> CourseTeeInfo? {
        teeInfos.first { $0.name == name }
    }

    var logoImage: UIImage? {
        guard let data = logoData else { return nil }
        return UIImage(data: data)
    }

    var photoImage: UIImage? {
        guard let data = photoData else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - CourseHole

@Model
final class CourseHole {
    var holeNumber: Int
    var name: String
    var par: Int
    var mensHdcp: Int
    var ladiesHdcp: Int
    var yardagesData: Data
    var course: Course?

    init(holeNumber: Int, name: String = "", par: Int = 4,
         mensHdcp: Int = 0, ladiesHdcp: Int = 0, yardages: [String: Int] = [:]) {
        self.holeNumber = holeNumber
        self.name = name
        self.par = par
        self.mensHdcp = mensHdcp
        self.ladiesHdcp = ladiesHdcp
        self.yardagesData = (try? JSONEncoder().encode(yardages)) ?? Data()
    }

    var yardages: [String: Int] {
        get {
            (try? JSONDecoder().decode([String: Int].self, from: yardagesData)) ?? [:]
        }
        set {
            yardagesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    func yardage(for teeName: String) -> Int {
        yardages[teeName] ?? 0
    }

    func toHoleInfo() -> HoleInfo {
        HoleInfo(number: holeNumber, name: name, par: par,
                 mensHdcp: mensHdcp, ladiesHdcp: ladiesHdcp, yardages: yardages)
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        if hex.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
