import SwiftUI

/// Bottom sheet (~40% of the screen) opened with the ⋯ button next to the plan name.
struct PlanMenuSheet: View {
    let planID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var detent: PresentationDetent = .fraction(0.4)
    @State private var showRoutines = false
    @State private var showRename = false
    @State private var showDelete = false
    @State private var draft = ""

    private var planName: String { store.plan(planID)?.name ?? "Plan" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        draft = planName
                        showRename = true
                    } label: {
                        row("Rename Plan", icon: "pencil")
                    }
                    Button {
                        store.duplicatePlan(planID)
                        dismiss()
                    } label: {
                        row("Duplicate Plan", icon: "plus.square.on.square")
                    }
                    Button {
                        detent = .large
                        showRoutines = true
                    } label: {
                        row("Manage Routines", icon: "list.bullet", chevron: true)
                    }
                }
                Section {
                    Button(role: .destructive) {
                        showDelete = true
                    } label: {
                        Label("Delete Plan", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(planName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showRoutines) {
                RoutineManagementView(planID: planID)
            }
            .alert("Rename Plan", isPresented: $showRename) {
                TextField("Plan name", text: $draft)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let name = draft.trimmed
                    if !name.isEmpty { store.renamePlan(planID, to: name) }
                }
            }
            .alert("Delete plan?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) {
                    store.deletePlan(planID)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("“\(planName)” and all of its routines will be permanently deleted. This can't be undone.")
            }
        }
        .presentationDetents([.fraction(0.4), .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private func row(_ title: String, icon: String, chevron: Bool = false) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// List of routines in a plan: rename / duplicate / delete, drag ☰ to reorder, Add Routine.
struct RoutineManagementView: View {
    let planID: UUID

    @Environment(AppStore.self) private var store

    @State private var targetID: UUID?
    @State private var targetName = ""
    @State private var showRename = false
    @State private var showDelete = false
    @State private var showAdd = false
    @State private var draft = ""

    var body: some View {
        let routines = store.plan(planID)?.routines ?? []
        List {
            Section {
                ForEach(routines) { routine in
                    routineRow(routine)
                }
                .onMove { source, destination in
                    store.moveRoutines(planID: planID, from: source, to: destination)
                }
            } footer: {
                Text("Hold ☰ and drag to change the order.")
            }

            Section {
                Button {
                    draft = ""
                    showAdd = true
                } label: {
                    Label("Add Routine", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename Routine", isPresented: $showRename) {
            TextField("Routine name", text: $draft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = draft.trimmed
                if let id = targetID, !name.isEmpty {
                    store.renameRoutine(planID: planID, routineID: id, to: name)
                }
            }
        }
        .alert("Delete routine?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                if let id = targetID {
                    store.deleteRoutine(planID: planID, routineID: id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(targetName)” and its exercises will be deleted.")
        }
        .alert("New Routine", isPresented: $showAdd) {
            TextField("Routine name", text: $draft)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let name = draft.trimmed
                if !name.isEmpty { store.addRoutine(planID: planID, name: name) }
            }
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.body.weight(.medium))
                Text("\(routine.exercises.count) \(routine.exercises.count == 1 ? "exercise" : "exercises")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button {
                    draft = routine.name
                    targetID = routine.id
                    showRename = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    store.duplicateRoutine(planID: planID, routineID: routine.id)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Button(role: .destructive) {
                    targetID = routine.id
                    targetName = routine.name
                    showDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
    }
}
