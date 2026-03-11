import SwiftUI

struct BagEditorView: View {
    @ObservedObject private var bag = BagManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Club.allCases, id: \.rawValue) { club in
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                bag.toggle(club)
                            }
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: bag.clubs.contains(club) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(bag.clubs.contains(club) ? AppTheme.fairwayGreen : Color(.systemGray3))
                                Text(club.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("Toggle clubs in your bag")
                } footer: {
                    Text("\(bag.clubs.count) clubs selected · only these will appear in club pickers during a round")
                }
            }
            .navigationTitle("My Bag")
            .toolbarBackground(AppTheme.darkGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
