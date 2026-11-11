import SwiftUI

enum ExerciseCardAction {
    case edit
    case replace
    case manageAlternatives
    case switchTo(UUID)
    case delete
}

/// Exercises of one routine shown as cards. Supersets are chained together.
struct RoutinePageView: View {
    let planID: UUID
    let routine: Routine

    @Environment(AppStore.self) private var store
    @State private var editing: RoutineExercise?
    @State private var replacing: RoutineExercise?
    @State private var alternativesFor: RoutineExercise?

    var body: some View {
        ScrollView {
            if routine.exercises.isEmpty {
                ContentUnavailableView {
                    Label("No exercises yet", systemImage: "dumbbell")
                } description: {
                    Text("Tap + below to add exercises to \(routine.name).")
                }
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(ExerciseBlock.make(from: routine.exercises)) { block in
                        ExerciseBlockView(block: block) { item, action in
                            handle(action, for: item)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 130)
            }
        }
        .sheet(item: $editing) { item in
            NavigationStack {
                ExerciseConfigView(exercise: store.exercise(item.exerciseID) ?? Exercise.missing(id: item.exerciseID),
                                   existing: item) { updated in
                    store.updateExercise(updated, planID: planID, routineID: routine.id)
                }
            }
        }
        .sheet(item: $replacing) { item in
            ExercisePickerView(onAdd: { _ in },
                               title: "Replace \(store.exercise(item.exerciseID)?.name ?? "Exercise")",
                               onPick: { exercise in
                                   store.replaceExercise(slotID: item.id, with: exercise.id,
                                                         planID: planID, routineID: routine.id)
                               })
        }
        .sheet(item: $alternativesFor) { item in
            AlternativesView(planID: planID, routineID: routine.id, slotID: item.id)
        }
    }

    private func handle(_ action: ExerciseCardAction, for item: RoutineExercise) {
        switch action {
        case .edit:
            editing = item
        case .replace:
            replacing = item
        case .manageAlternatives:
            alternativesFor = item
        case .switchTo(let optionID):
            withAnimation(.snappy) {
                store.switchToAlternative(slotID: item.id, optionID: optionID, planID: planID, routineID: routine.id)
            }
        case .delete:
            store.deleteExercise(item.id, planID: planID, routineID: routine.id)
        }
    }
}

struct ExerciseBlock: Identifiable {
    let id: UUID
    let items: [RoutineExercise]

    static func make(from list: [RoutineExercise]) -> [ExerciseBlock] {
        var blocks: [ExerciseBlock] = []
        var current: [RoutineExercise] = []
        for (index, item) in list.enumerated() {
            current.append(item)
            if !item.supersetWithNext || index == list.count - 1 {
                blocks.append(ExerciseBlock(id: current[0].id, items: current))
                current = []
            }
        }
        return blocks
    }
}

struct ExerciseBlockView: View {
    let block: ExerciseBlock
    let onAction: (RoutineExercise, ExerciseCardAction) -> Void

    @Environment(AppStore.self) private var store

    var body: some View {
        if block.items.count == 1, let item = block.items.first {
            card(item)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Label("SUPERSET", systemImage: "link")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                    .padding(.leading, 6)
                    .padding(.bottom, 6)
                ForEach(Array(block.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        ChainConnector()
                    }
                    card(item)
                }
            }
        }
    }

    private func card(_ item: RoutineExercise) -> some View {
        ExerciseCardView(item: item)
            .contentShape(Rectangle())
            .onTapGesture { onAction(item, .edit) }
            .contextMenu {
                Button {
                    onAction(item, .edit)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    onAction(item, .replace)
                } label: {
                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                }
                Menu {
                    ForEach(item.alternatives) { option in
                        Button {
                            onAction(item, .switchTo(option.id))
                        } label: {
                            Label("Use \(store.exercise(option.exerciseID)?.name ?? "Unknown exercise")",
                                  systemImage: "arrow.left.arrow.right")
                        }
                    }
                    if !item.alternatives.isEmpty {
                        Divider()
                    }
                    Button {
                        onAction(item, .manageAlternatives)
                    } label: {
                        Label(item.alternatives.isEmpty ? "Add Alternative" : "Manage Alternatives",
                              systemImage: "list.bullet")
                    }
                } label: {
                    Label("Alternative", systemImage: "arrow.left.arrow.right")
                }
                Divider()
                Button(role: .destructive) {
                    onAction(item, .delete)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

/// The chain link drawn between two cards of a superset.
struct ChainConnector: View {
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(Theme.accent.opacity(0.6))
                    .frame(width: 3)
                Image(systemName: "link")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.accent))
            }
            .frame(width: 22, height: 26)
            .padding(.leading, 39)
            Spacer()
        }
        .frame(height: 26)
    }
}

struct ExerciseCardView: View {
    let item: RoutineExercise
    @Environment(AppStore.self) private var store

    var body: some View {
        let exercise = store.exercise(item.exerciseID)
        HStack(alignment: .top, spacing: 12) {
            ExerciseImageView(exercise: exercise, animated: true)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise?.name ?? "Unknown exercise")
                    .font(.headline)
                    .lineLimit(2)
                Text(exercise?.muscleLine ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label("Rest \(Fmt.rest(item.restSeconds))", systemImage: "timer")
                    Label("\(item.sets.count) \(item.sets.count == 1 ? "set" : "sets")", systemImage: "square.stack.3d.up")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(Fmt.setsSummary(item.sets, mode: item.mode))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(2)
                if item.mode == .weightReps, let target = item.target.text {
                    Label("Target \(target)", systemImage: "scope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if !item.alternatives.isEmpty {
                    Label("or " + alternativeNames, systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
    }

    private var alternativeNames: String {
        item.alternatives
            .map { store.exercise($0.exerciseID)?.name ?? "Unknown exercise" }
            .joined(separator: " / ")
    }
}

/// Small row used in the superset and reorder screens.
struct CompactExerciseRow: View {
    let item: RoutineExercise
    @Environment(AppStore.self) private var store

    var body: some View {
        let exercise = store.exercise(item.exerciseID)
        HStack(spacing: 12) {
            ExerciseImageView(exercise: exercise, animated: false)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise?.name ?? "Unknown exercise")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(Fmt.setsSummary(item.sets, mode: item.mode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
