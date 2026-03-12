import SwiftUI
import CloudKit

struct FriendsListView: View {
    @ObservedObject private var ck = CloudKitManager.shared
    @State private var showAddFriend = false
    @State private var friendCode = ""
    @State private var lookupError: String?
    @State private var isSearching = false

    var body: some View {
        List {
            if !ck.iCloudAvailable {
                iCloudUnavailable
            } else {
                if !ck.pendingRequests.isEmpty {
                    pendingSection
                }
                friendsSection
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if ck.iCloudAvailable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        friendCode = ""
                        lookupError = nil
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(AppTheme.gold)
                    }
                }
            }
        }
        .refreshable {
            await ck.fetchFriends()
            await ck.fetchPendingRequests()
        }
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

    // MARK: - Sections

    private var iCloudUnavailable: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("iCloud Required")
                    .font(.headline)
                Text("Sign in to iCloud in Settings to add friends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private var pendingSection: some View {
        Section("Pending Requests") {
            ForEach(ck.pendingRequests, id: \.recordID) { request in
                let name = request["fromName"] as? String ?? "Someone"
                let code = request["fromCode"] as? String ?? ""
                HStack {
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
            }
        }
    }

    private var friendsSection: some View {
        Section("Friends (\(ck.friends.count))") {
            if ck.friends.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No friends yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap + to add a friend by their code.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(ck.friends, id: \.recordID) { friendship in
                    NavigationLink {
                        FriendProfileView(friendship: friendship)
                    } label: {
                        friendRow(friendship)
                    }
                }
            }
        }
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
    }

    // MARK: - Add Friend Logic

    private func searchAndAdd() {
        let code = friendCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }

        if code == ck.friendCode {
            lookupError = "That's your own friend code!"
            return
        }

        Task {
            isSearching = true
            defer { isSearching = false }

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
