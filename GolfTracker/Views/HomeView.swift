import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.date, order: .reverse) private var allRounds: [Round]

    @State private var activeRound: Round?
    @State private var showActiveRound = false
    @State private var showTeeSelector = false

    private var completedRounds: [Round] { allRounds.filter(\.isComplete) }
    private var incompleteRounds: [Round] { allRounds.filter { !$0.isComplete } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader
                    VStack(spacing: 16) {
                        if let active = incompleteRounds.first {
                            inProgressCard(active)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        newRoundButton
                        if !completedRounds.isEmpty {
                            completedSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !allRounds.isEmpty {
                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.35)) {
                                for r in allRounds { modelContext.delete(r) }
                                try? modelContext.save()
                            }
                            Haptics.medium()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if completedRounds.isEmpty {
                        Button {
                            MockDataGenerator.generate(in: modelContext)
                            Haptics.success()
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(AppTheme.gold)
                        }
                    }
                }
            }
            .toolbarBackground(AppTheme.darkGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showActiveRound, onDismiss: {
            activeRound = nil
        }) {
            if let round = activeRound {
                ActiveRoundView(round: round) { showActiveRound = false }
            }
        }
        .sheet(isPresented: $showTeeSelector) {
            TeeSelectionView { tee in
                showTeeSelector = false
                createRound(tee: tee)
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Text("Haymaker")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            if completedRounds.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.gold)
                    Text("Ready to play?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 8)
            } else {
                let avg = Double(completedRounds.map(\.totalScore).reduce(0, +)) / Double(completedRounds.count)
                let avgPutts = Double(completedRounds.map(\.totalPutts).reduce(0, +)) / Double(completedRounds.count)
                HStack(spacing: 0) {
                    heroStat(value: String(format: "%.0f", avg), label: "AVG SCORE")
                    heroDivider
                    heroStat(value: String(format: "%.0f", avgPutts), label: "AVG PUTTS")
                    heroDivider
                    heroStat(value: "\(completedRounds.count)", label: "ROUNDS")
                }
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(AppTheme.headerGradient)
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AppTheme.gold)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    // MARK: - In Progress Card

    private func inProgressCard(_ round: Round) -> some View {
        Button {
            Haptics.medium()
            openRound(round)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.fairwayGreen)
                        .frame(width: 44, height: 44)
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue round")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Circle().fill(round.tee.color).frame(width: 8, height: 8)
                        Text("\(round.tee.rawValue) · \(round.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - New Round Button

    private var newRoundButton: some View {
        Button {
            Haptics.medium()
            handlePlusTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.headline)
                Text("New round")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                LinearGradient(colors: [AppTheme.fairwayGreen, AppTheme.darkGreen], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            )
            .shadow(color: AppTheme.fairwayGreen.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completed

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("History")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 4)
            .padding(.top, 4)

            VStack(spacing: 1) {
                ForEach(Array(completedRounds.enumerated()), id: \.element.id) { i, round in
                    NavigationLink {
                        RoundDetailView(round: round)
                    } label: {
                        RoundRowView(round: round)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(AppTheme.cardBackground)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.35)) {
                                modelContext.delete(round)
                                try? modelContext.save()
                            }
                            Haptics.light()
                        } label: {
                            Label("Delete round", systemImage: "trash")
                        }
                    }
                    if i < completedRounds.count - 1 {
                        Divider().padding(.leading, 16)
                            .background(AppTheme.cardBackground)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Actions

    private func handlePlusTap() {
        if let existing = incompleteRounds.first {
            openRound(existing)
        } else {
            showTeeSelector = true
        }
    }

    private func openRound(_ round: Round) {
        activeRound = round
        showActiveRound = true
    }

    private func createRound(tee: Tee) {
        let round = Round(date: .now, isComplete: false, tee: tee)
        modelContext.insert(round)
        for hole in Haymaker.holes {
            let hs = HoleScore(holeNumber: hole.number, score: hole.par, putts: 2)
            hs.round = round
            modelContext.insert(hs)
        }
        try? modelContext.save()
        Haptics.success()
        openRound(round)
    }
}

// MARK: - Tee Selection

struct TeeSelectionView: View {
    var onSelect: (Tee) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ForEach(Tee.allCases, id: \.self) { tee in
                    Button {
                        Haptics.medium()
                        onSelect(tee)
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(tee.color)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(color: tee.color.opacity(0.3), radius: 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tee.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(tee.totalYardage) yds · \(tee.rating)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Select tees")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Round Row

struct RoundRowView: View {
    let round: Round

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    Circle().fill(round.tee.color).frame(width: 8, height: 8)
                    Text(round.tee.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", round.fairwayPct))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("FWY")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(round.totalPutts)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("PUTTS")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(round.totalScore)")
                        .font(.title3.bold().monospacedDigit())
                    Text(round.scoreToParString)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.scoreColor(round.scoreToPar))
                }
            }
        }
    }
}
