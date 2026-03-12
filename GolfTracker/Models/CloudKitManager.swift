import CloudKit
import SwiftUI

@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container = CKContainer(identifier: "iCloud.com.ryanshaw.GolfTracker")
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    static let userProfileType = "UserProfile"
    static let sharedRoundType = "SharedRound"
    static let friendshipType = "Friendship"

    @Published var userProfile: CKRecord?
    @Published var friends: [CKRecord] = []
    @Published var pendingRequests: [CKRecord] = []
    @Published var iCloudAvailable = false
    @Published var isLoading = false

    @Published var localFriends: [LocalFriend] = []
    @Published var localFriendRounds: [String: [SharedRoundSummary]] = [:]

    private init() {
        loadLocalFriends()
    }

    // MARK: - Local Friends Persistence

    private static let localFriendsKey = "localFriends"

    private func loadLocalFriends() {
        if let data = UserDefaults.standard.data(forKey: Self.localFriendsKey),
           let friends = try? JSONDecoder().decode([LocalFriend].self, from: data) {
            localFriends = friends
        }
    }

    private func saveLocalFriends() {
        if let data = try? JSONEncoder().encode(localFriends) {
            UserDefaults.standard.set(data, forKey: Self.localFriendsKey)
        }
    }

    func addLocalFriend(_ friend: LocalFriend, rounds: [SharedRoundSummary]) {
        localFriends.removeAll { $0.id == friend.id }
        localFriends.append(friend)
        localFriendRounds[friend.id] = rounds
        saveLocalFriends()
    }

    func removeLocalFriend(_ friend: LocalFriend) {
        localFriends.removeAll { $0.id == friend.id }
        localFriendRounds.removeValue(forKey: friend.id)
        saveLocalFriends()
    }

    // MARK: - Setup

    func setup() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let status = try await container.accountStatus()
            iCloudAvailable = status == .available
        } catch {
            iCloudAvailable = false
            return
        }

        guard iCloudAvailable else { return }
        await fetchOrCreateProfile()
        await fetchFriends()
        await fetchPendingRequests()
    }

    // MARK: - User Profile

    var displayName: String {
        userProfile?["displayName"] as? String ?? "Golfer"
    }

    var friendCode: String {
        userProfile?["friendCode"] as? String ?? ""
    }

    func fetchOrCreateProfile() async {
        do {
            let userRecordID = try await container.userRecordID()
            let predicate = NSPredicate(format: "creatorUserRecordID == %@", userRecordID)
            let query = CKQuery(recordType: Self.userProfileType, predicate: predicate)
            let (results, _) = try await publicDB.records(matching: query)
            let records = results.compactMap { try? $0.1.get() }

            if let existing = records.first {
                userProfile = existing
            } else {
                let record = CKRecord(recordType: Self.userProfileType)
                record["displayName"] = "Golfer" as CKRecordValue
                record["friendCode"] = generateFriendCode() as CKRecordValue
                record["homeCourse"] = "" as CKRecordValue
                let saved = try await publicDB.save(record)
                userProfile = saved
            }
        } catch {
            print("CloudKit profile error: \(error)")
        }
    }

    func updateDisplayName(_ name: String) async {
        guard let profile = userProfile else { return }
        profile["displayName"] = name as CKRecordValue
        do {
            let saved = try await publicDB.save(profile)
            userProfile = saved
        } catch {
            print("CloudKit update name error: \(error)")
        }
    }

    func updateHomeCourse(_ course: String) async {
        guard let profile = userProfile else { return }
        profile["homeCourse"] = course as CKRecordValue
        do {
            let saved = try await publicDB.save(profile)
            userProfile = saved
        } catch {
            print("CloudKit update course error: \(error)")
        }
    }

    // MARK: - Friend Code

    private func generateFriendCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let suffix = String((0..<4).map { _ in chars.randomElement()! })
        return "HMK-\(suffix)"
    }

    // MARK: - Friend Lookup

    func lookupUser(byCode code: String) async -> CKRecord? {
        let predicate = NSPredicate(format: "friendCode == %@", code.uppercased())
        let query = CKQuery(recordType: Self.userProfileType, predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(matching: query)
            return results.compactMap({ try? $0.1.get() }).first
        } catch {
            return nil
        }
    }

    // MARK: - Friendships

    func sendFriendRequest(to targetProfile: CKRecord) async -> Bool {
        guard let myProfile = userProfile else { return false }

        let friendship = CKRecord(recordType: Self.friendshipType)
        friendship["fromUser"] = CKRecord.Reference(record: myProfile, action: .none) as CKRecordValue
        friendship["toUser"] = CKRecord.Reference(record: targetProfile, action: .none) as CKRecordValue
        friendship["fromName"] = (myProfile["displayName"] as? String ?? "Golfer") as CKRecordValue
        friendship["toName"] = (targetProfile["displayName"] as? String ?? "Golfer") as CKRecordValue
        friendship["fromCode"] = (myProfile["friendCode"] as? String ?? "") as CKRecordValue
        friendship["toCode"] = (targetProfile["friendCode"] as? String ?? "") as CKRecordValue
        friendship["status"] = "pending" as CKRecordValue
        friendship["requestedDate"] = Date() as CKRecordValue

        do {
            try await publicDB.save(friendship)
            await fetchFriends()
            await fetchPendingRequests()
            return true
        } catch {
            print("Friend request error: \(error)")
            return false
        }
    }

    func acceptFriendRequest(_ friendship: CKRecord) async {
        friendship["status"] = "accepted" as CKRecordValue
        do {
            try await publicDB.save(friendship)
            await fetchFriends()
            await fetchPendingRequests()
        } catch {
            print("Accept error: \(error)")
        }
    }

    func declineFriendRequest(_ friendship: CKRecord) async {
        do {
            try await publicDB.deleteRecord(withID: friendship.recordID)
            await fetchPendingRequests()
        } catch {
            print("Decline error: \(error)")
        }
    }

    func removeFriend(_ friendship: CKRecord) async {
        do {
            try await publicDB.deleteRecord(withID: friendship.recordID)
            await fetchFriends()
        } catch {
            print("Remove friend error: \(error)")
        }
    }

    func fetchFriends() async {
        guard let profile = userProfile else { return }
        let ref = CKRecord.Reference(record: profile, action: .none)
        var all: [CKRecord] = []

        let pred1 = NSPredicate(format: "fromUser == %@ AND status == %@", ref, "accepted")
        if let (r1, _) = try? await publicDB.records(matching: CKQuery(recordType: Self.friendshipType, predicate: pred1)) {
            all.append(contentsOf: r1.compactMap { try? $0.1.get() })
        }

        let pred2 = NSPredicate(format: "toUser == %@ AND status == %@", ref, "accepted")
        if let (r2, _) = try? await publicDB.records(matching: CKQuery(recordType: Self.friendshipType, predicate: pred2)) {
            all.append(contentsOf: r2.compactMap { try? $0.1.get() })
        }

        friends = all
    }

    func fetchPendingRequests() async {
        guard let profile = userProfile else { return }
        let ref = CKRecord.Reference(record: profile, action: .none)
        let predicate = NSPredicate(format: "toUser == %@ AND status == %@", ref, "pending")
        let query = CKQuery(recordType: Self.friendshipType, predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(matching: query)
            pendingRequests = results.compactMap { try? $0.1.get() }
        } catch {
            print("Pending requests error: \(error)")
        }
    }

    /// Returns the friend's name from a friendship record (the other person, not you).
    func friendDisplayName(from friendship: CKRecord) -> String {
        guard let myProfile = userProfile else { return "Friend" }
        let myRef = CKRecord.Reference(record: myProfile, action: .none)
        if (friendship["fromUser"] as? CKRecord.Reference)?.recordID == myRef.recordID {
            return friendship["toName"] as? String ?? "Friend"
        }
        return friendship["fromName"] as? String ?? "Friend"
    }

    /// Returns the friend's code from a friendship record.
    func friendCodeValue(from friendship: CKRecord) -> String {
        guard let myProfile = userProfile else { return "" }
        let myRef = CKRecord.Reference(record: myProfile, action: .none)
        if (friendship["fromUser"] as? CKRecord.Reference)?.recordID == myRef.recordID {
            return friendship["toCode"] as? String ?? ""
        }
        return friendship["fromCode"] as? String ?? ""
    }

    /// Fetches the friend's UserProfile record from a friendship.
    func friendProfile(from friendship: CKRecord) async -> CKRecord? {
        guard let myProfile = userProfile else { return nil }
        let myRef = CKRecord.Reference(record: myProfile, action: .none)

        let friendRef: CKRecord.Reference?
        if (friendship["fromUser"] as? CKRecord.Reference)?.recordID == myRef.recordID {
            friendRef = friendship["toUser"] as? CKRecord.Reference
        } else {
            friendRef = friendship["fromUser"] as? CKRecord.Reference
        }

        guard let ref = friendRef else { return nil }
        do {
            return try await publicDB.record(for: ref.recordID)
        } catch {
            return nil
        }
    }

    // MARK: - Round Publishing

    func publishRound(_ round: Round) async {
        guard let profile = userProfile else { return }

        let recordName = "round-\(Int(round.date.timeIntervalSince1970))-\(round.totalScore)"
        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: Self.sharedRoundType, recordID: recordID)

        record["owner"] = CKRecord.Reference(record: profile, action: .deleteSelf) as CKRecordValue
        record["courseName"] = round.courseName as CKRecordValue
        record["tee"] = round.teeRaw as CKRecordValue
        record["date"] = round.date as CKRecordValue
        record["totalScore"] = round.totalScore as CKRecordValue
        record["scoreToPar"] = round.scoreToPar as CKRecordValue
        record["holesPlayed"] = round.holesPlayed as CKRecordValue
        record["totalPutts"] = round.totalPutts as CKRecordValue
        record["fairwayPct"] = round.fairwayPct as CKRecordValue
        record["girPct"] = round.girPct as CKRecordValue
        record["front9Score"] = round.front9Score as CKRecordValue
        record["back9Score"] = round.back9Score as CKRecordValue
        record["hasFull18"] = (round.hasFull18 ? 1 : 0) as CKRecordValue
        record["hasFront9"] = (round.hasFront9 ? 1 : 0) as CKRecordValue
        record["hasBack9"] = (round.hasBack9 ? 1 : 0) as CKRecordValue

        let holeData: [[String: Any]] = round.sortedScores.map { score in
            [
                "hole": score.holeNumber,
                "score": score.score,
                "par": score.par,
                "putts": score.putts,
                "teeResult": score.teeResultRaw,
                "approachResult": score.approachResultRaw,
                "approachDistance": score.approachDistance,
                "hitFairway": score.hitFairway,
                "hitGreen": score.hitGreen
            ]
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: holeData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            record["holeScoresJSON"] = jsonString as CKRecordValue
        }

        do {
            try await publicDB.save(record)
        } catch {
            print("Publish round error: \(error)")
        }
    }

    func fetchFriendRounds(friendProfile: CKRecord) async -> [SharedRoundSummary] {
        let ref = CKRecord.Reference(record: friendProfile, action: .none)
        let predicate = NSPredicate(format: "owner == %@", ref)
        let query = CKQuery(recordType: Self.sharedRoundType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query)
            return results.compactMap { try? $0.1.get() }.map { SharedRoundSummary.from($0) }
        } catch {
            print("Fetch friend rounds error: \(error)")
            return []
        }
    }

    func backfillRounds(_ rounds: [Round]) async {
        for round in rounds where round.isComplete {
            await publishRound(round)
        }
    }
}
