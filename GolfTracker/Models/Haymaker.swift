import Foundation

struct HoleInfo {
    let number: Int
    let name: String
    let par: Int
    let mensHdcp: Int
    let ladiesHdcp: Int
    let yardages: [Tee: Int]

    func yardage(for tee: Tee) -> Int {
        yardages[tee] ?? 0
    }
}

struct Haymaker {
    static let name = "Haymaker"

    static func hole(_ number: Int) -> HoleInfo {
        holes[number - 1]
    }

    static let holes: [HoleInfo] = [
        HoleInfo(number: 1,  name: "Rabbit Ears",     par: 4, mensHdcp: 15, ladiesHdcp: 7,
                 yardages: [.silver: 408, .gold: 362, .white: 349, .blue: 279, .family: 230]),
        HoleInfo(number: 2,  name: "Westward Ho",     par: 4, mensHdcp: 7,  ladiesHdcp: 15,
                 yardages: [.silver: 423, .gold: 390, .white: 368, .blue: 259, .family: 245]),
        HoleInfo(number: 3,  name: "Old Tom",         par: 4, mensHdcp: 5,  ladiesHdcp: 3,
                 yardages: [.silver: 456, .gold: 436, .white: 375, .blue: 346, .family: 235]),
        HoleInfo(number: 4,  name: "Flat Tops",       par: 4, mensHdcp: 1,  ladiesHdcp: 5,
                 yardages: [.silver: 457, .gold: 420, .white: 375, .blue: 322, .family: 250]),
        HoleInfo(number: 5,  name: "Redan",           par: 3, mensHdcp: 13, ladiesHdcp: 13,
                 yardages: [.silver: 211, .gold: 185, .white: 172, .blue: 135, .family: 127]),
        HoleInfo(number: 6,  name: "Cattle Drive",    par: 5, mensHdcp: 3,  ladiesHdcp: 1,
                 yardages: [.silver: 636, .gold: 590, .white: 577, .blue: 429, .family: 380]),
        HoleInfo(number: 7,  name: "Respite",         par: 3, mensHdcp: 17, ladiesHdcp: 17,
                 yardages: [.silver: 175, .gold: 146, .white: 128, .blue: 112, .family: 112]),
        HoleInfo(number: 8,  name: "Ring the Bell",   par: 4, mensHdcp: 9,  ladiesHdcp: 9,
                 yardages: [.silver: 347, .gold: 310, .white: 276, .blue: 221, .family: 221]),
        HoleInfo(number: 9,  name: "Goin' to Town",   par: 5, mensHdcp: 11, ladiesHdcp: 11,
                 yardages: [.silver: 537, .gold: 515, .white: 485, .blue: 423, .family: 360]),
        HoleInfo(number: 10, name: "Waterloo",        par: 4, mensHdcp: 2,  ladiesHdcp: 6,
                 yardages: [.silver: 454, .gold: 406, .white: 400, .blue: 322, .family: 260]),
        HoleInfo(number: 11, name: "Watering Hole",   par: 4, mensHdcp: 12, ladiesHdcp: 12,
                 yardages: [.silver: 343, .gold: 318, .white: 291, .blue: 229, .family: 229]),
        HoleInfo(number: 12, name: "Greywall",        par: 3, mensHdcp: 14, ladiesHdcp: 18,
                 yardages: [.silver: 163, .gold: 152, .white: 116, .blue: 75,  .family: 75]),
        HoleInfo(number: 13, name: "Around the Bend", par: 5, mensHdcp: 10, ladiesHdcp: 10,
                 yardages: [.silver: 546, .gold: 525, .white: 459, .blue: 382, .family: 320]),
        HoleInfo(number: 14, name: "Black Diamond",   par: 4, mensHdcp: 4,  ladiesHdcp: 8,
                 yardages: [.silver: 479, .gold: 429, .white: 399, .blue: 326, .family: 230]),
        HoleInfo(number: 15, name: "Mackenzie",       par: 4, mensHdcp: 8,  ladiesHdcp: 4,
                 yardages: [.silver: 439, .gold: 403, .white: 366, .blue: 311, .family: 240]),
        HoleInfo(number: 16, name: "Emerald View",    par: 4, mensHdcp: 6,  ladiesHdcp: 2,
                 yardages: [.silver: 424, .gold: 402, .white: 363, .blue: 311, .family: 220]),
        HoleInfo(number: 17, name: "Ten Gallon",      par: 3, mensHdcp: 16, ladiesHdcp: 16,
                 yardages: [.silver: 248, .gold: 218, .white: 172, .blue: 141, .family: 110]),
        HoleInfo(number: 18, name: "To the Barn",     par: 5, mensHdcp: 18, ladiesHdcp: 14,
                 yardages: [.silver: 562, .gold: 521, .white: 480, .blue: 436, .family: 330]),
    ]
}
