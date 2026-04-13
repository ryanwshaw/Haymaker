import SwiftUI
import SwiftData

struct FriendsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]
    @Query(filter: #Predicate<Match> { $0.isComplete }) private var completedMatches: [Match]

    @State private var showAddFriend = false
    @State private var newFriendName = ""
    @State private var newFriendStrokes = 0
    @State private var editingFriend: Friend?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if friends.isEmpty {
                    emptyState
                } else {
                    ForEach(friends) { friend in
                        friendCard(friend)
                    }
                }

                addFriendButton
                    .padding(.top, 8)
            }
            .padding()
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Add friend", isPresented: $showAddFriend) {
            TextField("Name", text: $newFriendName)
            Button("Add") {
                addFriend()
            }
            Button("Cancel", role: .cancel) {
                newFriendName = ""
                newFriendStrokes = 0
            }
        } message: {
            Text("Enter your friend's name to add them to your list.")
        }
        .sheet(item: $editingFriend) { friend in
            EditFriendSheet(friend: friend)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.gold)
                .symbolEffect(.pulse.byLayer, options: .repeating)

            Text("No friends yet")
                .font(.headline)
            Text("Add friends to quickly include them in matches and track your head-to-head history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func friendCard(_ friend: Friend) -> some View {
        let matchCount = matchesForFriend(friend).count
        let wins = winsAgainstFriend(friend)

        return NavigationLink {
            FriendDetailView(friend: friend)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.eagle.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text(friend.initial)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.eagle)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(friend.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text("HC \(friend.defaultHandicapStrokes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if matchCount > 0 {
                            Text("·")
                                .foregroundStyle(.quaternary)
                            Text("\(matchCount) match\(matchCount == 1 ? "" : "es")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if wins > 0 {
                                Text("·")
                                    .foregroundStyle(.quaternary)
                                Text("\(wins)W")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.fairwayGreen)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    editingFriend = friend
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Color.gray.opacity(0.3))
            }
            .padding(14)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var addFriendButton: some View {
        Button {
            showAddFriend = true
            Haptics.light()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.body)
                Text("Add friend")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(AppTheme.fairwayGreen)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(AppTheme.fairwayGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.fairwayGreen.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func addFriend() {
        let name = newFriendName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let friend = Friend(name: name, defaultHandicapStrokes: newFriendStrokes)
        modelContext.insert(friend)
        try? modelContext.save()
        newFriendName = ""
        newFriendStrokes = 0
        Haptics.success()
    }

    // MARK: - Match lookups

    func matchesForFriend(_ friend: Friend) -> [Match] {
        completedMatches.filter { match in
            match.players.contains { $0.friendId == friend.stableId }
        }
    }

    func winsAgainstFriend(_ friend: Friend) -> Int {
        var wins = 0
        for match in matchesForFriend(friend) {
            guard let userPlayer = match.userPlayer else { continue }
            let friendPlayer = match.players.first { $0.friendId == friend.stableId }
            guard let fp = friendPlayer else { continue }
            if userPlayer.totalGross < fp.totalGross && userPlayer.totalGross > 0 {
                wins += 1
            }
        }
        return wins
    }
}

// MARK: - Edit Friend Sheet

struct EditFriendSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var friend: Friend
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $friend.name)
                }
                Section("Default handicap strokes") {
                    Stepper("\(friend.defaultHandicapStrokes)", value: $friend.defaultHandicapStrokes, in: 0...36)
                }
                Section {
                    Button("Delete friend", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .alert("Delete \(friend.name)?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(friend)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove them from your friends list. Match history will be preserved.")
            }
        }
    }
}
