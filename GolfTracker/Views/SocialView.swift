import SwiftUI
import SwiftData

struct SocialView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var ck = CloudKitManager.shared
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]
    @Query(sort: \Friend.name) private var friends: [Friend]
    @Query(filter: #Predicate<Match> { $0.isComplete }, sort: \Match.date, order: .reverse) private var completedMatches: [Match]

    @ObservedObject private var auth = AuthManager.shared

    @State private var showAddFriend = false
    @State private var newFriendName = ""
    @State private var showEditName = false
    @State private var editNameText = ""

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                comingSoonBanner.staggeredAppear(index: 0)
                profileCard.staggeredAppear(index: 1)
                myFriendsSection.staggeredAppear(index: 2)

                if !completedMatches.isEmpty {
                    recentMatchesSection.staggeredAppear(index: 3)
                }

                Color.clear.frame(height: 16)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .alert("Add friend", isPresented: $showAddFriend) {
            TextField("Name", text: $newFriendName)
            Button("Add") {
                let name = newFriendName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let friend = Friend(name: name)
                modelContext.insert(friend)
                try? modelContext.save()
                newFriendName = ""
                Haptics.success()
            }
            Button("Cancel", role: .cancel) { newFriendName = "" }
        } message: {
            Text("Add a friend to quickly include them in matches.")
        }
        .alert("Your Name", isPresented: $showEditName) {
            TextField("Name", text: $editNameText)
            Button("Save") {
                auth.setCustomName(editNameText)
                Haptics.success()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This name is shown on your profile and in matches.")
        }
    }

    // MARK: - Coming Soon Banner

    private var comingSoonBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Coming Soon")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.gold)
                Text("Live match challenges, friend leaderboards, and more.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.gold.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.gold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(AppTheme.gold.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.fairwayGreen.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Text(String(auth.displayName.prefix(1)).uppercased())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.fairwayGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(auth.displayName)
                            .font(.headline)
                        Button {
                            editNameText = auth.displayName == "Golfer" ? "" : auth.displayName
                            showEditName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(completedRounds.count) rounds · \(completedMatches.count) matches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            NavigationLink {
                BadgeProfileView(
                    playerName: auth.displayName,
                    badges: BadgeManager.shared.earnedBadges
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "medal.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mauve)
                    Text("My Badges")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(BadgeManager.shared.earnedBadges.count)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(AppTheme.mauve)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Friends Section

    private var myFriendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Friends (\(friends.count))")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                Spacer()
                NavigationLink {
                    FriendsListView()
                } label: {
                    Text("Manage")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.fairwayGreen)
                }
                .buttonStyle(.plain)
            }

            if friends.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.mauve)

                    Text("Add friends to include them in matches and track head-to-head records.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showAddFriend = true
                        Haptics.light()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.caption)
                            Text("Add your first friend")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.fairwayGreen, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(friends.prefix(5).enumerated()), id: \.element.id) { i, friend in
                        NavigationLink {
                            FriendDetailView(friend: friend)
                        } label: {
                            friendRow(friend)
                        }
                        .buttonStyle(.plain)

                        if i < min(friends.count, 5) - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }

                    if friends.count > 5 {
                        Divider()
                        NavigationLink {
                            FriendsListView()
                        } label: {
                            Text("See all \(friends.count) friends")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.fairwayGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)

                Button {
                    showAddFriend = true
                    Haptics.light()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add friend")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(AppTheme.fairwayGreen)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(AppTheme.fairwayGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func friendRow(_ friend: Friend) -> some View {
        let matchCount = completedMatches.filter { m in m.players.contains { $0.friendId == friend.stableId } }.count

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.eagle.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(friend.initial)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.eagle)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text("HC \(friend.defaultHandicapStrokes)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if matchCount > 0 {
                        Text("· \(matchCount) match\(matchCount == 1 ? "" : "es")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.gray.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Recent Matches

    private var recentMatchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Matches")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(completedMatches.prefix(5).enumerated()), id: \.element.id) { i, match in
                    recentMatchRow(match)
                    if i < min(completedMatches.count, 5) - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
    }

    private func recentMatchRow(_ match: Match) -> some View {
        let otherNames = match.sortedPlayers.filter { !$0.isUser }.map(\.name).joined(separator: ", ")
        let userScore = match.userPlayer?.totalGross ?? 0
        let courseName = match.round?.courseName ?? ""

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.mauveLight)
                    .frame(width: 38, height: 38)
                Image(systemName: match.gameType.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.mauve)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(match.gameType.displayName)
                    .font(.subheadline.bold())
                Text("vs \(otherNames)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(courseName) · \(match.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.gray.opacity(0.5))
            }

            Spacer()

            if userScore > 0 {
                Text("\(userScore)")
                    .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
