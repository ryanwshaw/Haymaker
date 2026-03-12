import Foundation
import SwiftData

struct MockDataGenerator {
    static func generate(in context: ModelContext) {
        let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.name == "Haymaker" })
        let course: Course
        if let existing = try? context.fetch(descriptor).first {
            course = existing
        } else {
            course = Haymaker.seed(in: context)
        }

        let teeDistribution: [String] = [
            "Gold", "Gold", "Gold", "Gold", "Gold",
            "White", "White", "White", "White", "White",
            "Gold", "Gold", "White", "Gold", "White",
            "Silver", "Gold", "White", "Blue", "Gold"
        ]

        let driveResults4 = ["fairway", "fairway", "fairway", "rough_left", "rough_right", "native", "bunker"]
        let greenResults = ["green", "green", "green", "short", "long", "left", "right", "bunker"]
        let teeClubs4: [String] = ["Driver", "Driver", "Driver", "3 Wood"]
        let teeClubs3: [String] = ["7 Iron", "8 Iron", "6 Iron", "5 Iron", "9 Iron", "PW", "Hybrid"]
        let approachClubs: [String] = ["PW", "GW", "SW", "9 Iron", "8 Iron", "7 Iron", "6 Iron", "5 Iron", "Hybrid"]
        let chipClubs: [String] = ["SW", "LW", "GW", "PW"]

        let courseHoles = course.sortedHoles

        for i in 0..<20 {
            let daysAgo = Double(i * 5 + seeded(i, max: 4))
            let date = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: .now)!
            let teeName = teeDistribution[i]
            let round = Round(date: date, isComplete: true, tee: teeName, course: course)
            context.insert(round)

            for hole in courseHoles {
                let isPar3 = hole.par == 3
                let isPar5 = hole.par == 5
                let seed = i * 18 + hole.holeNumber

                let scoreDelta: Int
                let roll = seeded(seed, max: 100)
                if roll < 3 { scoreDelta = -2 }
                else if roll < 18 { scoreDelta = -1 }
                else if roll < 50 { scoreDelta = 0 }
                else if roll < 78 { scoreDelta = 1 }
                else if roll < 92 { scoreDelta = 2 }
                else { scoreDelta = 3 }
                let holeScore = hole.par + scoreDelta

                let putts: Int
                let puttRoll = seeded(seed + 500, max: 100)
                if puttRoll < 8 { putts = 1 }
                else if puttRoll < 75 { putts = 2 }
                else if puttRoll < 95 { putts = 3 }
                else { putts = 0 }

                let teeResult: String
                let teeClub: String
                if isPar3 {
                    teeResult = pick(greenResults, seed: seed + 100)
                    teeClub = pick(teeClubs3, seed: seed + 101)
                } else {
                    teeResult = pick(driveResults4, seed: seed + 100)
                    teeClub = pick(teeClubs4, seed: seed + 101)
                }

                let approachDist: Int
                let approachResult: String
                let approachClub: String
                if isPar3 {
                    approachDist = 0
                    approachResult = ""
                    approachClub = ""
                } else {
                    let baseDist = isPar5 ? 190 : 140
                    let variation = seeded(seed + 200, max: 80) - 40
                    let raw = baseDist + variation
                    approachDist = (raw / 10) * 10
                    approachResult = pick(greenResults, seed: seed + 201)
                    approachClub = pick(approachClubs, seed: seed + 202)
                }

                let hitGreen = isPar3 ? (teeResult == "green") : (approachResult == "green")
                let chipClub = hitGreen ? "" : pick(chipClubs, seed: seed + 300)

                let firstPuttDist = seeded(seed + 400, max: 35) + 3
                let penalties = scoreDelta >= 3 ? 1 : 0

                let hs = HoleScore(
                    holeNumber: hole.holeNumber,
                    score: max(holeScore, 1),
                    putts: putts,
                    holePar: hole.par,
                    holeName: hole.name,
                    holeYardage: hole.yardage(for: teeName),
                    holeMensHdcp: hole.mensHdcp,
                    teeResultRaw: teeResult,
                    teeClubRaw: teeClub,
                    approachDistance: approachDist,
                    approachResultRaw: approachResult,
                    approachClubRaw: approachClub,
                    chipClubRaw: chipClub,
                    firstPuttDistance: firstPuttDist,
                    greensideBunker: teeResult == "bunker" || approachResult == "bunker",
                    penalties: penalties
                )
                hs.round = round
                context.insert(hs)
            }
        }

        try? context.save()
    }

    // MARK: - Mock Friend Data

    static func generateMockFriend() -> (friend: LocalFriend, rounds: [SharedRoundSummary]) {
        let friend = LocalFriend(id: "mock-jake", name: "Jake", code: "HMK-J4K3")

        let tees = ["Gold", "Gold", "White", "Gold", "White",
                     "Gold", "Gold", "White", "Gold", "White",
                     "Gold", "White", "Gold", "White", "Gold"]

        let driveResults = ["fairway", "fairway", "fairway", "fairway", "rough_left", "rough_right", "fairway"]
        let greenResults = ["green", "green", "green", "green", "short", "long", "left", "green"]

        var rounds: [SharedRoundSummary] = []

        for i in 0..<15 {
            let daysAgo = Double(i * 6 + seeded(i + 777, max: 5))
            let date = Calendar.current.date(byAdding: .day, value: -Int(daysAgo), to: .now)!
            let teeName = tees[i]

            var holeScores: [SharedHoleScore] = []
            var totalScore = 0
            var totalPutts = 0
            var totalPar = 0

            for holeNum in 1...18 {
                let info = Haymaker.hole(holeNum)
                let isPar3 = info.par == 3
                let seed = (i + 50) * 18 + holeNum + 3000

                let roll = seeded(seed, max: 100)
                let scoreDelta: Int
                if roll < 5 { scoreDelta = -2 }
                else if roll < 25 { scoreDelta = -1 }
                else if roll < 58 { scoreDelta = 0 }
                else if roll < 82 { scoreDelta = 1 }
                else if roll < 94 { scoreDelta = 2 }
                else { scoreDelta = 3 }

                let score = max(info.par + scoreDelta, 1)
                let puttRoll = seeded(seed + 600, max: 100)
                let putts = puttRoll < 12 ? 1 : (puttRoll < 80 ? 2 : 3)

                let teeResult: String
                if isPar3 {
                    teeResult = pick(greenResults, seed: seed + 150)
                } else {
                    teeResult = pick(driveResults, seed: seed + 150)
                }

                let approachResult: String
                let approachDist: Int
                if isPar3 {
                    approachResult = ""
                    approachDist = 0
                } else {
                    approachResult = pick(greenResults, seed: seed + 250)
                    let base = info.par == 5 ? 180 : 130
                    approachDist = ((base + seeded(seed + 251, max: 70) - 35) / 10) * 10
                }

                let hitFairway = teeResult == "fairway"
                let hitGreen = isPar3 ? (teeResult == "green") : (approachResult == "green")

                holeScores.append(SharedHoleScore(
                    holeNumber: holeNum,
                    score: score,
                    par: info.par,
                    putts: putts,
                    teeResult: teeResult,
                    approachResult: approachResult,
                    approachDistance: approachDist,
                    hitFairway: hitFairway,
                    hitGreen: hitGreen
                ))

                totalScore += score
                totalPutts += putts
                totalPar += info.par
            }

            let front9 = holeScores.filter { $0.holeNumber <= 9 }
            let back9 = holeScores.filter { $0.holeNumber >= 10 }
            let fwyPossible = holeScores.filter { $0.par != 3 }
            let fwyHit = fwyPossible.filter(\.hitFairway)
            let girHit = holeScores.filter(\.hitGreen)

            rounds.append(SharedRoundSummary(
                id: "mock-jake-\(i)",
                courseName: "Haymaker",
                tee: teeName,
                date: date,
                totalScore: totalScore,
                scoreToPar: totalScore - totalPar,
                holesPlayed: 18,
                totalPutts: totalPutts,
                fairwayPct: fwyPossible.isEmpty ? 0 : Double(fwyHit.count) / Double(fwyPossible.count) * 100,
                girPct: Double(girHit.count) / Double(holeScores.count) * 100,
                front9Score: front9.map(\.score).reduce(0, +),
                back9Score: back9.map(\.score).reduce(0, +),
                hasFull18: true,
                hasFront9: true,
                hasBack9: true,
                holeScores: holeScores
            ))
        }

        return (friend, rounds)
    }

    private static func seeded(_ seed: Int, max: Int) -> Int {
        var s = UInt64(abs(seed) &+ 0x9E3779B9)
        s = (s ^ (s >> 16)) &* 0x45d9f3b
        s = (s ^ (s >> 16)) &* 0x45d9f3b
        s = s ^ (s >> 16)
        return Int(s % UInt64(max))
    }

    private static func pick(_ arr: [String], seed: Int) -> String {
        arr[seeded(seed, max: arr.count)]
    }
}
