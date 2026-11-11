import SwiftUI

/// Link neighbouring exercises into supersets with the chain buttons between cards.
struct EditSupersetView: View {
    let planID: UUID
    let routineID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var items: [RoutineExercise]

    init(planID: UUID, routineID: UUID, exercises: [RoutineExercise]) {
        self.planID = planID
        self.routineID = routineID
        _items = State(initialValue: exercises)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text("Tap the chain between two exercises to join them into a superset. Reorder exercises first if they aren't next to each other.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 14)

                    ForEach(items.indices, id: \.self) { index in
                        CompactExerciseRow(item: items[index])
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                        if index < items.count - 1 {
                            LinkToggleRow(isOn: $items[index].supersetWithNext)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.setExercises(items, planID: planID, routineID: routineID)
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
    }
}

struct LinkToggleRow: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "link" : "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isOn ? Theme.onAccent : Color.secondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isOn ? Theme.accent : Theme.card))
                    .overlay(
                        Circle().strokeBorder(isOn ? Color.clear : Color.secondary.opacity(0.5),
                                              style: StrokeStyle(lineWidth: 1, dash: [3]))
                    )
                Text(isOn ? "Superset" : "Link as superset")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOn ? Theme.accent : Color.secondary)
                Spacer()
            }
            .padding(.leading, 18)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Drag ☰ to change the order of exercises.
struct ReorderExercisesView: View {
    let planID: UUID
    let routineID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var items: [RoutineExercise]

    init(planID: UUID, routineID: UUID, exercises: [RoutineExercise]) {
        self.planID = planID
        self.routineID = routineID
        _items = State(initialValue: exercises)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    CompactExerciseRow(item: item)
                }
                .onMove { source, destination in
                    items.move(fromOffsets: source, toOffset: destination)
                }
            }
            .themedList()
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.setExercises(items, planID: planID, routineID: routineID)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
