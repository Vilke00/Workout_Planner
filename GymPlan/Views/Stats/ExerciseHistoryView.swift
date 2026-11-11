import SwiftUI

/// History of one exercise by date. By default only shows sessions where the numbers changed.
struct ExerciseHistoryView: View {
    let exerciseID: String
    let title: String

    @Environment(AppStore.self) private var store
    @State private var showAll = false

    var body: some View {
        let entries = store.history(for: exerciseID, onlyChanges: !showAll)
        List {
            if entries.isEmpty {
                ContentUnavailableView("No history yet",
                                       systemImage: "clock.arrow.circlepath",
                                       description: Text("Finish a workout with this exercise and it will show up here."))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    bestRow
                }
            .listRowBackground(Theme.card)
                Section {
                    ForEach(entries) { entry in
                        HistoryRow(entry: entry)
                    }
                } header: {
                    Text(showAll ? "All sessions" : "When the numbers changed")
                }
            .listRowBackground(Theme.card)
            }
        }
            .themedList()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Show", selection: $showAll) {
                        Text("Only changes").tag(false)
                        Text("All sessions").tag(true)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var bestRow: some View {
        let all = store.history(for: exerciseID, onlyChanges: false)
        let sets = all.flatMap { $0.sets }
        let mode = all.first?.mode ?? .weightReps
        HStack(spacing: 0) {
            if mode == .weightReps {
                stat("Best weight", value: "\(Fmt.num(sets.map(\.weight).max() ?? 0)) kg")
                stat("Best reps", value: "\(sets.map(\.reps).max() ?? 0)")
            } else {
                stat("Longest", value: "\(Fmt.num(sets.map(\.minutes).max() ?? 0)) min")
                stat("Farthest", value: "\(Fmt.num(sets.map(\.meters).max() ?? 0)) m")
            }
            stat("Sessions", value: "\(all.count)")
        }
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.weight(.semibold))
            Text(Fmt.loggedSummary(entry.sets, mode: entry.mode))
                .font(.body.monospacedDigit())
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 2)
    }
}
