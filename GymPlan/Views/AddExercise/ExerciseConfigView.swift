import SwiftUI
import UIKit

/// Set up an exercise for a routine: type, sets (reps × kg or min × meters) and rest.
struct ExerciseConfigView: View {
    let exercise: Exercise
    let existing: RoutineExercise?
    /// Alternatives share the slot's rest, so their setup hides it.
    let showsRest: Bool
    let onSave: (RoutineExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: TrackingMode
    @State private var rows: [EditableSet]
    @State private var restSeconds: Int
    @State private var repMin: String
    @State private var repMax: String
    @State private var amrap: Bool
    @State private var showRestPicker = false
    @FocusState private var focus: FieldID?

    enum FieldID: Hashable {
        case first(UUID)
        case second(UUID)
        case repMin
        case repMax
    }

    init(exercise: Exercise, existing: RoutineExercise?, showsRest: Bool = true,
         onSave: @escaping (RoutineExercise) -> Void) {
        self.exercise = exercise
        self.existing = existing
        self.showsRest = showsRest
        self.onSave = onSave
        let startMode: TrackingMode = existing?.mode ?? (exercise.prefersTime ? .timeDistance : .weightReps)
        let startSets: [SetTemplate]
        if let existing {
            startSets = existing.sets
        } else if startMode == .timeDistance {
            startSets = [SetTemplate(reps: 0, minutes: exercise.kind == .stretch ? 0.5 : 10)]
        } else {
            startSets = [SetTemplate(), SetTemplate(), SetTemplate()]
        }
        _mode = State(initialValue: startMode)
        _rows = State(initialValue: startSets.map { EditableSet($0) })
        _restSeconds = State(initialValue: existing?.restSeconds ?? 0)
        let target = existing?.target ?? RepTarget.empty
        _repMin = State(initialValue: target.min.map(String.init) ?? "")
        _repMax = State(initialValue: target.max.map(String.init) ?? "")
        _amrap = State(initialValue: target.amrap)
    }

    var body: some View {
        List {
            Section { header }
            .listRowBackground(Theme.card)

            Section {
                Picker("Type", selection: $mode) {
                    ForEach(TrackingMode.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                columnHeader
                ForEach($rows) { $row in
                    setRow(number: number(of: row), row: $row)
                }
                .onDelete { offsets in
                    rows.remove(atOffsets: offsets)
                }
                Button {
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
            } footer: {
                Text("Swipe a set to the left to delete it.")
            }
            .listRowBackground(Theme.card)

            if mode == .weightReps {
                targetSection
            }

            if showsRest {
            Section {
                Button {
                    focus = nil
                    showRestPicker = true
                } label: {
                    HStack {
                        Label("Rest", systemImage: "timer")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(Fmt.rest(restSeconds))
                            .foregroundStyle(restSeconds > 0 ? Theme.accent : Color.secondary)
                            .font(.body.weight(.semibold).monospacedDigit())
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } footer: {
                Text("Rest between sets of this exercise.")
            }
            .listRowBackground(Theme.card)
            }
        }
            .themedList()
        .navigationTitle(existing == nil ? "Add Exercise" : "Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showRestPicker) {
            RestPickerSheet(seconds: $restSeconds, title: "Rest Between Sets")
        }
    }

    private var targetSection: some View {
        Section {
            Toggle("AMRAP / to failure", isOn: $amrap)
            if !amrap {
                HStack(spacing: 8) {
                    Text("Rep range")
                    Spacer()
                    rangeField("8", text: $repMin, field: .repMin)
                    Text("–")
                        .foregroundStyle(.secondary)
                    rangeField("12", text: $repMax, field: .repMax)
                }
            }
        } header: {
            Text("Target reps")
        } footer: {
            Text("Shown during the workout. When you reach the top of the range, the next workout asks for the bottom of the range with more weight.")
        }
            .listRowBackground(Theme.card)
    }

    private func rangeField(_ placeholder: String, text: Binding<String>, field: FieldID) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.body.weight(.semibold).monospacedDigit())
            .frame(width: 56)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card2))
            .focused($focus, equals: field)
    }

    private var currentTarget: RepTarget {
        guard mode == .weightReps else { return RepTarget.empty }
        if amrap { return RepTarget(amrap: true) }
        let low = Int(repMin.trimmed).map { max(0, $0) }
        let high = Int(repMax.trimmed).map { max(0, $0) }
        return RepTarget(min: low, max: high)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if existing != nil {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(existing == nil ? "Add" : "Save") { save() }
                .bold()
                .disabled(rows.isEmpty)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focus = nil }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 14) {
            ExerciseImageView(exercise: exercise, animated: true)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                Text(exercise.muscleLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !exercise.equipmentTags.isEmpty {
                    Text(exercise.equipmentTags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var columnHeader: some View {
        HStack(spacing: 12) {
            Text("Set").frame(width: 40)
            Text(mode.firstLabel).frame(maxWidth: .infinity)
            Text(mode.secondLabel).frame(maxWidth: .infinity)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func setRow(number: Int, row: Binding<EditableSet>) -> some View {
        let id = row.wrappedValue.id
        let isWeight = mode == .weightReps
        return HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(width: 40)
            numberField(isWeight ? row.reps : row.minutes,
                        keyboard: isWeight ? .numberPad : .decimalPad,
                        field: .first(id))
            numberField(isWeight ? row.weight : row.meters,
                        keyboard: .decimalPad,
                        field: .second(id))
        }
    }

    private func numberField(_ text: Binding<String>, keyboard: UIKeyboardType, field: FieldID) -> some View {
        TextField("0", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.body.weight(.semibold).monospacedDigit())
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card2))
            .focused($focus, equals: field)
    }

    private func number(of row: EditableSet) -> Int {
        (rows.firstIndex { $0.id == row.id } ?? 0) + 1
    }

    // MARK: Actions

    private func addSet() {
        var copy = rows.last ?? EditableSet(SetTemplate())
        copy.id = UUID()
        rows.append(copy)
    }

    private func save() {
        focus = nil
        let sets = rows.map { $0.template() }
        guard !sets.isEmpty else { return }
        let item = RoutineExercise(id: existing?.id ?? UUID(),
                                   exerciseID: exercise.id,
                                   mode: mode,
                                   sets: sets,
                                   restSeconds: restSeconds,
                                   supersetWithNext: existing?.supersetWithNext ?? false,
                                   target: currentTarget,
                                   alternatives: existing?.alternatives ?? [])
        onSave(item)
        if existing != nil { dismiss() }
    }
}

/// Text-backed copy of a set so typing ("62,5", empty field) feels natural.
struct EditableSet: Identifiable {
    var id: UUID
    var reps: String
    var weight: String
    var minutes: String
    var meters: String

    init(_ set: SetTemplate) {
        id = set.id
        reps = set.reps > 0 ? String(set.reps) : ""
        weight = set.weight > 0 ? Fmt.num(set.weight) : ""
        minutes = set.minutes > 0 ? Fmt.num(set.minutes) : ""
        meters = set.meters > 0 ? Fmt.num(set.meters) : ""
    }

    func template() -> SetTemplate {
        SetTemplate(id: id,
                    reps: Fmt.parseInt(reps),
                    weight: Fmt.parseDouble(weight),
                    minutes: Fmt.parseDouble(minutes),
                    meters: Fmt.parseDouble(meters))
    }
}
