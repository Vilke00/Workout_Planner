import SwiftUI

/// Search + Muscle / Equipment / Category filters + list of all exercises.
struct ExercisePickerView: View {
    let onAdd: (RoutineExercise) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var muscle: String?
    @State private var equipment: String?
    @State private var kind: ExerciseKind?

    private var results: [Exercise] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        return store.allExercises.filter { exercise in
            if let muscle, !exercise.primaryMuscles.contains(where: { $0.lowercased() == muscle }) { return false }
            if let equipment, !exercise.equipmentTags.contains(equipment) { return false }
            if let kind, exercise.kind != kind { return false }
            if !words.isEmpty {
                let name = exercise.name.lowercased()
                return words.allSatisfy { name.contains($0) }
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            let list = results
            List {
                if list.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(list) { exercise in
                        NavigationLink(value: exercise) {
                            ExercisePickerRow(exercise: exercise)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .top, spacing: 0) {
                filterBar(count: list.count)
            }
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search exercise by name")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseConfigView(exercise: exercise, existing: nil) { newItem in
                    onAdd(newItem)
                    dismiss()
                }
            }
        }
    }

    private func filterBar(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    muscleMenu
                    equipmentMenu
                    categoryMenu
                }
                .padding(.horizontal)
            }
            Text("\(count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var muscleMenu: some View {
        Menu {
            Picker("Muscle", selection: $muscle) {
                Text("Any Muscle").tag(String?.none)
                ForEach(store.muscleOptions, id: \.self) { value in
                    Text(Fmt.title(value)).tag(String?.some(value))
                }
            }
        } label: {
            FilterChip(title: muscle.map(Fmt.title) ?? "Any Muscle", icon: "figure.arms.open", isActive: muscle != nil)
        }
    }

    private var equipmentMenu: some View {
        Menu {
            Picker("Equipment", selection: $equipment) {
                Text("Any Equipment").tag(String?.none)
                ForEach(store.equipmentOptions, id: \.self) { value in
                    Text(value).tag(String?.some(value))
                }
            }
        } label: {
            FilterChip(title: equipment ?? "Any Equipment", icon: "dumbbell", isActive: equipment != nil)
        }
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: $kind) {
                Text("Any").tag(ExerciseKind?.none)
                ForEach(ExerciseKind.allCases) { value in
                    Text(value.title).tag(ExerciseKind?.some(value))
                }
            }
        } label: {
            FilterChip(title: kind?.title ?? "Any Category", icon: "square.grid.2x2", isActive: kind != nil)
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .background(Capsule().fill(isActive ? Theme.accent : Theme.card))
    }
}

struct ExercisePickerRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            ExerciseImageView(exercise: exercise, animated: false)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(exercise.muscleLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !exercise.equipmentTags.isEmpty {
                    Text(exercise.equipmentTags.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
