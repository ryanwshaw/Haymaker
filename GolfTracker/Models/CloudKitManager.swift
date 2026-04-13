import SwiftUI

@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    @Published var iCloudAvailable = false
    @Published var isLoading = false

    @Published var localFriends: [LocalFriend] = []
    @Published var localFriendRounds: [String: [SharedRoundSummary]] = [:]
    @Published var localFriendBadges: [String: [EarnedBadge]] = [:]

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

    func addLocalFriend(_ friend: LocalFriend, rounds: [SharedRoundSummary], badges: [EarnedBadge] = []) {
        localFriends.removeAll { $0.id == friend.id }
        localFriends.append(friend)
        localFriendRounds[friend.id] = rounds
        localFriendBadges[friend.id] = badges
        saveLocalFriends()
    }

    func removeLocalFriend(_ friend: LocalFriend) {
        localFriends.removeAll { $0.id == friend.id }
        localFriendRounds.removeValue(forKey: friend.id)
        localFriendBadges.removeValue(forKey: friend.id)
        saveLocalFriends()
    }

    var displayName: String {
        AuthManager.shared.displayName
    }

    var friendCode: String { "" }

    func setup() async {
        iCloudAvailable = false
    }

    func publishRound(_ round: Round) async { }
    func backfillRounds(_ rounds: [Round]) async { }
}
