import Foundation
import SwiftData

struct HoleInfo {
    let number: Int
    let name: String
    let par: Int
    let mensHdcp: Int
    let ladiesHdcp: Int
    let yardages: [String: Int]

    func yardage(for teeName: String) -> Int {
        yardages[teeName] ?? 0
    }
}

struct Haymaker {
    static let name = "Haymaker"

    static func hole(_ number: Int) -> HoleInfo {
        holes[number - 1]
    }

    static let tees: [CourseTeeInfo] = [
        CourseTeeInfo(name: "Silver", colorHex: "8E8E93", rating: "73.3/140", sortOrder: 0),
        CourseTeeInfo(name: "Gold",   colorHex: "FFD60A", rating: "70.1/131", sortOrder: 1),
        CourseTeeInfo(name: "White",  colorHex: "8E8E93", rating: "67.3/123", sortOrder: 2),
        CourseTeeInfo(name: "Blue",   colorHex: "007AFF", rating: "62.2/103", sortOrder: 3),
        CourseTeeInfo(name: "Family", colorHex: "FF3B30", rating: "—",        sortOrder: 4),
    ]

    static let holes: [HoleInfo] = [
        HoleInfo(number: 1,  name: "Rabbit Ears",     par: 4, mensHdcp: 15, ladiesHdcp: 7,
                 yardages: ["Silver": 408, "Gold": 362, "White": 349, "Blue": 279, "Family": 230]),
        HoleInfo(number: 2,  name: "Westward Ho",     par: 4, mensHdcp: 7,  ladiesHdcp: 15,
                 yardages: ["Silver": 423, "Gold": 390, "White": 368, "Blue": 259, "Family": 245]),
        HoleInfo(number: 3,  name: "Old Tom",         par: 4, mensHdcp: 5,  ladiesHdcp: 3,
                 yardages: ["Silver": 456, "Gold": 436, "White": 375, "Blue": 346, "Family": 235]),
        HoleInfo(number: 4,  name: "Flat Tops",       par: 4, mensHdcp: 1,  ladiesHdcp: 5,
                 yardages: ["Silver": 457, "Gold": 420, "White": 375, "Blue": 322, "Family": 250]),
        HoleInfo(number: 5,  name: "Redan",           par: 3, mensHdcp: 13, ladiesHdcp: 13,
                 yardages: ["Silver": 211, "Gold": 185, "White": 172, "Blue": 135, "Family": 127]),
        HoleInfo(number: 6,  name: "Cattle Drive",    par: 5, mensHdcp: 3,  ladiesHdcp: 1,
                 yardages: ["Silver": 636, "Gold": 590, "White": 577, "Blue": 429, "Family": 380]),
        HoleInfo(number: 7,  name: "Respite",         par: 3, mensHdcp: 17, ladiesHdcp: 17,
                 yardages: ["Silver": 175, "Gold": 146, "White": 128, "Blue": 112, "Family": 112]),
        HoleInfo(number: 8,  name: "Ring the Bell",   par: 4, mensHdcp: 9,  ladiesHdcp: 9,
                 yardages: ["Silver": 347, "Gold": 310, "White": 276, "Blue": 221, "Family": 221]),
        HoleInfo(number: 9,  name: "Goin' to Town",   par: 5, mensHdcp: 11, ladiesHdcp: 11,
                 yardages: ["Silver": 537, "Gold": 515, "White": 485, "Blue": 423, "Family": 360]),
        HoleInfo(number: 10, name: "Waterloo",        par: 4, mensHdcp: 2,  ladiesHdcp: 6,
                 yardages: ["Silver": 454, "Gold": 406, "White": 400, "Blue": 322, "Family": 260]),
        HoleInfo(number: 11, name: "Watering Hole",   par: 4, mensHdcp: 12, ladiesHdcp: 12,
                 yardages: ["Silver": 343, "Gold": 318, "White": 291, "Blue": 229, "Family": 229]),
        HoleInfo(number: 12, name: "Greywall",        par: 3, mensHdcp: 14, ladiesHdcp: 18,
                 yardages: ["Silver": 163, "Gold": 152, "White": 116, "Blue": 75,  "Family": 75]),
        HoleInfo(number: 13, name: "Around the Bend", par: 5, mensHdcp: 10, ladiesHdcp: 10,
                 yardages: ["Silver": 546, "Gold": 525, "White": 459, "Blue": 382, "Family": 320]),
        HoleInfo(number: 14, name: "Black Diamond",   par: 4, mensHdcp: 4,  ladiesHdcp: 8,
                 yardages: ["Silver": 479, "Gold": 429, "White": 399, "Blue": 326, "Family": 230]),
        HoleInfo(number: 15, name: "Mackenzie",       par: 4, mensHdcp: 8,  ladiesHdcp: 4,
                 yardages: ["Silver": 439, "Gold": 403, "White": 366, "Blue": 311, "Family": 240]),
        HoleInfo(number: 16, name: "Emerald View",    par: 4, mensHdcp: 6,  ladiesHdcp: 2,
                 yardages: ["Silver": 424, "Gold": 402, "White": 363, "Blue": 311, "Family": 220]),
        HoleInfo(number: 17, name: "Ten Gallon",      par: 3, mensHdcp: 16, ladiesHdcp: 16,
                 yardages: ["Silver": 248, "Gold": 218, "White": 172, "Blue": 141, "Family": 110]),
        HoleInfo(number: 18, name: "To the Barn",     par: 5, mensHdcp: 18, ladiesHdcp: 14,
                 yardages: ["Silver": 562, "Gold": 521, "White": 480, "Blue": 436, "Family": 330]),
    ]

    /// Creates a persisted Course from the static Haymaker data.
    @discardableResult
    static func seed(in context: ModelContext) -> Course {
        let course = Course(name: Haymaker.name, tees: Haymaker.tees)
        context.insert(course)

        for info in Haymaker.holes {
            let hole = CourseHole(
                holeNumber: info.number,
                name: info.name,
                par: info.par,
                mensHdcp: info.mensHdcp,
                ladiesHdcp: info.ladiesHdcp,
                yardages: info.yardages
            )
            hole.course = course
            context.insert(hole)
        }

        try? context.save()
        return course
    }
}
