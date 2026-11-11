import SwiftUI

/// Floating bar at the bottom of a routine: Add exercise, Play/Stop, More.
struct RoutineActionBar: View {
    let plan: Plan
    let routine: Routine

    @Environment(AppStore.self) private var store
    @Environment(WorkoutManager.self) private var workout

    @State private var showAddExercise = false
    @State private var showStart = false
    @State private var showStopOptions = false
    @State private var showEditSuperset = false
    @State private var showReorder = false
    @State private var showRename = false
    @State private var showDelete = false
    @State private var showEmptyAlert = false
    @State private var nameDraft = ""

    var body: some View {
        HStack(spacing: 30) {
            addButton
            playButton
            moreMenu
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06)))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .padding(.bottom, 12)
        .modifier(sheets)
        .alert("Rename Routine", isPresented: $showRename) {
            TextField("Routine name", text: $nameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = nameDraft.trimmed
                if !name.isEmpty { store.renameRoutine(planID: plan.id, routineID: routine.id, to: name) }
            }
        }
        .alert("Delete routine?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                store.deleteRoutine(planID: plan.id, routineID: routine.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(routine.name)” and its exercises will be deleted.")
        }
        .alert("No exercises", isPresented: $showEmptyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add at least one exercise to \(routine.name) before starting.")
        }
        .confirmationDialog("End current workout?", isPresented: $showStopOptions, titleVisibility: .visible) {
            Button("Finish & Save") { workout.finish() }
            Button("Discard Workout", role: .destructive) { workout.discard() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var sheets: RoutineSheets {
        RoutineSheets(plan: plan, routine: routine,
                      showAddExercise: $showAddExercise,
                      showStart: $showStart,
                      showEditSuperset: $showEditSuperset,
                      showReorder: $showReorder)
    }

    private var addButton: some View {
        Button {
            showAddExercise = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.bold))
                .frame(width: 50, height: 50)
                .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }

    private var playButton: some View {
        Button {
            if workout.isActive {
                showStopOptions = true
            } else if routine.exercises.isEmpty {
                showEmptyAlert = true
            } else {
                showStart = true
            }
        } label: {
            Image(systemName: workout.isActive ? "stop.fill" : "play.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(workout.isActive ? Theme.text : Theme.onAccent)
                .frame(width: 62, height: 62)
                .background(Circle().fill(workout.isActive ? Theme.danger : Theme.accent))
                .shadow(color: (workout.isActive ? Theme.danger : Theme.accent).opacity(0.55), radius: 12)
        }
    }

    private var moreMenu: some View {
        Menu {
            Button {
                showEditSuperset = true
            } label: {
                Label("Edit Superset", systemImage: "link")
            }
            .disabled(routine.exercises.count < 2)

            Button {
                showReorder = true
            } label: {
                Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
            }
            .disabled(routine.exercises.count < 2)

            Button {
                nameDraft = routine.name
                showRename = true
            } label: {
                Label("Rename Routine", systemImage: "pencil")
            }

            Button(role: .destructive) {
                showDelete = true
            } label: {
                Label("Delete Routine", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.bold))
                .frame(width: 50, height: 50)
                .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}

/// Sheets presented from the action bar (kept separate to keep type-checking fast).
struct RoutineSheets: ViewModifier {
    let plan: Plan
    let routine: Routine
    @Binding var showAddExercise: Bool
    @Binding var showStart: Bool
    @Binding var showEditSuperset: Bool
    @Binding var showReorder: Bool

    @Environment(AppStore.self) private var store

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showAddExercise) {
                ExercisePickerView { newExercise in
                    store.addExercise(newExercise, planID: plan.id, routineID: routine.id)
                }
            }
            .sheet(isPresented: $showStart) {
                StartWorkoutSheet(plan: plan, routine: routine)
            }
            .sheet(isPresented: $showEditSuperset) {
                EditSupersetView(planID: plan.id, routineID: routine.id, exercises: routine.exercises)
            }
            .sheet(isPresented: $showReorder) {
                ReorderExercisesView(planID: plan.id, routineID: routine.id, exercises: routine.exercises)
            }
    }
}
