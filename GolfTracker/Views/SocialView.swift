import SwiftUI
import SwiftData
import CloudKit

struct SocialView: View {
    @ObservedObject private var ck = CloudKitManager.shared
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @State private var showAddFriend = false
    @State private var friendCode = ""
    @State private var lookupError: String?

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }

    var body: some View {
        Group {
            if !ck.iCloudAvailable {
                iCloudUnavailable
            } else if ck.isLoading {
                loadingState
            } else {
                mainContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("Add Friend", isPresented: $showAddFriend) {
            TextField("Friend code (e.g. HMK-A7X2)", text: $friendCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Add") { searchAndAdd() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your friend's code to send a request.")
        }
        .alert("Error", isPresented: .init(
            get: { lookupError != nil },
            set: { if !$0 { lookupError = nil } }
        )) {
            Button("OK") { lookupError = nil }
        } message: {
            Text(lookupError ?? "")
        }
    }

    // MARK: - States

    private var iCloudUnavailable: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 60)
                Image(systemName: "icloud.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.gold.opacity(0.4))
                Text("iCloud Required")
                    .font(.title3.bold())
                Text("Sign in to iCloud in Settings to use social features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Connecting to iCloud...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                profileCard
                addFriendButton
                if !ck.pendingRequests.isEmpty {
                    pendingRequestsCard
                }
                friendsCard
                Color.clear.frame(height: 16)
            }
            .padding()
            .animation(.spring(response: 0.35), value: ck.friends.count)
            .animation(.spring(response: 0.35), value: ck.pendingRequests.count)
            .animation(.spring(response: 0.35), value: ck.localFriends.count)
        }
        .refreshable {
            await ck.fetchFriends()
            await ck.fetchPendingRequests()
        }
    }

    // MARK: - Add Friend Button

    private var addFriendButton: some View {
        Button {
            friendCode = ""
            lookupError = nil
            showAddFriend = true
        } label: {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.body.bold())
                Text("Add Friend by Code")
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.darkGreen.opacity(0.5))
            }
            .foregroundStyle(AppTheme.darkGreen)
            .padding(16)
            .background(AppTheme.gold, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: AppTheme.gold.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.fairwayGreen.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Text(String(ck.displayName.prefix(1)).uppercased())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.fairwayGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(ck.displayName)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Text(ck.friendCode)
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(AppTheme.fairwayGreen)
                        Button {
                            UIPasteboard.general.string = ck.friendCode
                            Haptics.success()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.gold)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.gold)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Pending Requests

    private var pendingRequestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Requests")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(ck.pendingRequests.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.double, in: Capsule())
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(ck.pendingRequests.enumerated()), id: \.element.recordID) { i, request in
                    pendingRow(request)
                    if i < ck.pendingRequests.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    private func pendingRow(_ request: CKRecord) -> some View {
        let name = request["fromName"] as? String ?? "Someone"
        let code = request["fromCode"] as? String ?? ""
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.bogey.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.bogey)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.bold())
                Text(code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task {
                    await ck.acceptFriendRequest(request)
                    Haptics.success()
                }
            } label: {
                Text("Accept")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.fairwayGreen, in: Capsule())
            }
            .buttonStyle(.plain)
            Button {
                Task {
                    await ck.declineFriendRequest(request)
                    Haptics.medium()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Friends Card

    private var totalFriendCount: Int { ck.friends.count + ck.localFriends.count }

    private var friendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Friends (\(totalFriendCount))")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if totalFriendCount == 0 {
                emptyFriendsCard
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(ck.localFriends.enumerated()), id: \.element.id) { i, localFriend in
                        NavigationLink {
                            LocalFriendProfileView(
                                friend: localFriend,
                                friendRounds: ck.localFriendRounds[localFriend.id] ?? []
                            )
                        } label: {
                            localFriendRow(localFriend)
                        }
                        .buttonStyle(.plain)
                        if i < ck.localFriends.count - 1 || !ck.friends.isEmpty {
                            Divider().padding(.leading, 56)
                        }
                    }
                    ForEach(Array(ck.friends.enumerated()), id: \.element.recordID) { i, friendship in
                        NavigationLink {
                            FriendProfileView(friendship: friendship)
                        } label: {
                            friendRow(friendship)
                        }
                        .buttonStyle(.plain)
                        if i < ck.friends.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    private var emptyFriendsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No friends yet")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text("Add a friend by code, or load sample data to preview.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            if ck.localFriends.isEmpty {
                Button {
                    let mock = MockDataGenerator.generateMockFriend()
                    ck.addLocalFriend(mock.friend, rounds: mock.rounds)
                    Haptics.success()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Load sample friend")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.fairwayGreen, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func localFriendRow(_ friend: LocalFriend) -> some View {
        let roundCount = ck.localFriendRounds[friend.id]?.count ?? 0
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.eagle.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(String(friend.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.eagle)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.subheadline.bold())
                Text("\(friend.code) · \(roundCount) rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func friendRow(_ friendship: CKRecord) -> some View {
        let name = ck.friendDisplayName(from: friendship)
        let code = ck.friendCodeValue(from: friendship)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.fairwayGreen.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.fairwayGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.bold())
                Text(code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Add Friend

    private func searchAndAdd() {
        let code = friendCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }

        if code == ck.friendCode {
            lookupError = "That's your own friend code!"
            return
        }

        Task {
            guard let profile = await ck.lookupUser(byCode: code) else {
                lookupError = "No user found with code \(code). Check the code and try again."
                return
            }

            let success = await ck.sendFriendRequest(to: profile)
            if success {
                Haptics.success()
            } else {
                lookupError = "Failed to send friend request. Try again."
            }
        }
    }
}
