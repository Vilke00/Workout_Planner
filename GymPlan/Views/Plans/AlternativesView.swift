import SwiftUI

/// Exercises that can be done instead of one in the routine ("Bench press OR Dips").
/// Each keeps its own sets, weights and rep range; "Use" makes it the active one.
struct AlternativesView: View {
    let planID: UUID
    let routineID: UUID
    let slotID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var editingOption: ExerciseOption?

    private var slot: RoutineExercise? {
        store.routine(planID: planID, routineID: routineID)?.exercises.first { $0.id == slotID }
    }

    var body: some View {
        NavigationStack {
            List {
                if let slot {
                    Section {
                        OptionRow(option: slot.activeOption, isActive: true)
                    } header: {
                        Text("Doing now")
                    }
            .listRowBackground(Theme.card)

                    Section {
                        if slot.alternatives.isEmpty {
                            Text("No alternatives yet. Add an exercise you can do instead, for example Dips instead of Bench Press.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(slot.alternatives) { option in
                            HStack(spacing: 10) {
                                OptionRow(option: option, isActive: false)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingOption = option }
                                Button("Use") {
                                    withAnimation(.snappy) {
                                        store.switchToAlternative(slotID: slotID, optionID: option.id,
                                                                  planID: planID, routineID: routineID)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .foregroundStyle(Theme.onAccent)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.removeAlternative(optionID: option.id, slotID: slotID,
                                                            planID: planID, routineID: routineID)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        Button {
                            showAdd = true
                        } label: {
                            Label("Add Alternative", systemImage: "plus")
                        }
                    } header: {
                        Text("Alternatives")
                    } footer: {
                        Text("Tap Use to do that exercise instead. Tap an alternative to edit its sets and rep range, swipe left to delete it.")
                    }
            .listRowBackground(Theme.card)
                } else {
                    Text("This exercise was deleted.")
                        .foregroundStyle(.secondary)
                }
            }
            .themedList()
            .navigationTitle("Alternatives")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
            .sheet(isPresented: $showAdd) {
                ExercisePickerView(onAdd: { item in
                    let option = ExerciseOption(exerciseID: item.exerciseID, mode: item.mode,
                                                sets: item.sets, target: item.target)
                    store.addAlternative(option, slotID: slotID, planID: planID, routineID: routineID)
                }, title: "Add Alternative", showsRest: false)
            }
            .sheet(item: $editingOption) { option in
                NavigationStack {
                    ExerciseConfigView(exercise: store.exercise(option.exerciseID) ?? Exercise.missing(id: option.exerciseID),
                                       existing: RoutineExercise(id: option.id, exerciseID: option.exerciseID,
                                                                 mode: option.mode, sets: option.sets,
                                                                 target: option.target),
                                       showsRest: false) { updated in
                        let changed = ExerciseOption(id: option.id, exerciseID: updated.exerciseID, mode: updated.mode,
                                                     sets: updated.sets, target: updated.target)
                        store.updateAlternative(changed, slotID: slotID, planID: planID, routineID: routineID)
                    }
                }
            }
        }
    }
}

private struct OptionRow: View {
    let option: ExerciseOption
    let isActive: Bool

    @Environment(AppStore.self) private var store

    var body: some View {
        let exercise = store.exercise(option.exerciseID)
        HStack(spacing: 12) {
            ExerciseImageView(exercise: exercise, animated: false)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise?.name ?? "Unknown exercise")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(Fmt.setsSummary(option.sets, mode: option.mode))
                    .font(.caption)
                    .foregroundStyle(isActive ? Theme.accent : Color.secondary)
                    .lineLimit(1)
                if option.mode == .weightReps, let target = option.target.text {
                    Text("Target \(target)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
