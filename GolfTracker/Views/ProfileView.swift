import SwiftUI

struct ProfileView: View {
    @ObservedObject private var ck = CloudKitManager.shared
    @State private var editName = ""
    @State private var isEditing = false
    @State private var copied = false

    var body: some View {
        List {
            Section {
                if !ck.iCloudAvailable {
                    iCloudUnavailable
                } else if ck.userProfile == nil {
                    HStack {
                        ProgressView()
                        Text("Setting up profile...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    profileCard
                }
            }

            if ck.userProfile != nil {
                Section("Friend Code") {
                    friendCodeRow
                }

                Section {
                    displayNameRow
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if ck.userProfile == nil {
                await ck.setup()
            }
            editName = ck.displayName
        }
    }

    private var iCloudUnavailable: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("iCloud Not Available")
                .font(.headline)
            Text("Sign in to iCloud in Settings to use social features.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.fairwayGreen.opacity(0.15))
                    .frame(width: 56, height: 56)
                Text(String(ck.displayName.prefix(1)).uppercased())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.fairwayGreen)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(ck.displayName)
                    .font(.headline)
                Text(ck.friendCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.icloud.fill")
                .foregroundStyle(AppTheme.fairwayGreen)
        }
    }

    private var friendCodeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ck.friendCode)
                    .font(.title2.monospaced().bold())
                    .foregroundStyle(AppTheme.fairwayGreen)
                Text("Share this code with friends so they can add you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = ck.friendCode
                copied = true
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.body.bold())
                    .foregroundStyle(copied ? AppTheme.fairwayGreen : AppTheme.gold)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
    }

    private var displayNameRow: some View {
        HStack {
            Text("Display Name")
            Spacer()
            if isEditing {
                TextField("Name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .submitLabel(.done)
                    .onSubmit { saveName() }
                Button("Save") { saveName() }
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.fairwayGreen)
            } else {
                Text(ck.displayName)
                    .foregroundStyle(.secondary)
                Button {
                    editName = ck.displayName
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(AppTheme.gold)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func saveName() {
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isEditing = false
        Task {
            await ck.updateDisplayName(trimmed)
        }
        Haptics.success()
    }
}
