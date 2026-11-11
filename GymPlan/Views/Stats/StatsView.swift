import SwiftUI
import UIKit

struct StatsView: View {
    enum Page: String, CaseIterable, Identifiable {
        case workouts = "Workouts"
        case exercises = "Exercises"
        var id: String { rawValue }
    }

    @State private var page: Page = .workouts

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $page) {
                    ForEach(Page.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                switch page {
                case .workouts:
                    WorkoutLogList()
                case .exercises:
                    PerformedExerciseList()
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

// MARK: - Workouts

struct WorkoutLogList: View {
    @Environment(AppStore.self) private var store
    @State private var deleteID: UUID?
    @State private var showDelete = false

    var body: some View {
        if store.logs.isEmpty {
            ContentUnavailableView("No workouts yet",
                                   systemImage: "figure.strengthtraining.traditional",
                                   description: Text("Finished workouts show up here with the muscles you trained."))
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.logs) { log in
                        NavigationLink {
                            WorkoutLogDetailView(logID: log.id)
                        } label: {
                            WorkoutLogCard(log: log)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteID = log.id
                                showDelete = true
                            } label: {
                                Label("Delete Workout", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .alert("Delete this workout?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) {
                    if let id = deleteID { store.deleteLog(id) }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct WorkoutLogCard: View {
    let log: WorkoutLog

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(log.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.headline)
                Text(log.planName.isEmpty ? log.routineName : "\(log.routineName) · \(log.planName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label(Fmt.duration(log.duration), systemImage: "clock")
                    Label("\(log.totalSets) sets", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if log.volume > 0 {
                    Label("\(Fmt.num(log.volume)) kg volume", systemImage: "scalemass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(muscleText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            BodyMapView(primary: log.primaryMuscles, secondary: log.secondaryMuscles)
                .frame(width: 112, height: 108)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
    }

    private var muscleText: String {
        log.primaryMuscles.sorted().map(Fmt.title).joined(separator: ", ")
    }
}

struct WorkoutLogDetailView: View {
    let logID: UUID

    @Environment(AppStore.self) private var store
    @State private var editTarget: LoggedSetRef?

    var body: some View {
        if let log = store.logs.first(where: { $0.id == logID }) {
            List {
                Section {
                    HStack {
                        Spacer()
                        BodyMapView(primary: log.primaryMuscles, secondary: log.secondaryMuscles)
                            .frame(height: 200)
                        Spacer()
                    }
                    LabeledContent("Duration", value: Fmt.duration(log.duration))
                    LabeledContent("Sets", value: "\(log.totalSets)")
                    if log.volume > 0 {
                        LabeledContent("Volume", value: "\(Fmt.num(log.volume)) kg")
                    }
                }
            .listRowBackground(Theme.card)
                ForEach(log.exercises) { exercise in
                    Section {
                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                            Button {
                                editTarget = LoggedSetRef(logID: log.id, exerciseID: exercise.id, setIndex: index,
                                                          mode: exercise.mode, name: exercise.name, set: set)
                            } label: {
                                HStack {
                                    Text("Set \(index + 1)")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(Fmt.setValue(set, mode: exercise.mode))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.primary)
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.deleteLoggedSet(logID: log.id, exerciseID: exercise.id, setIndex: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text(exercise.name)
                    } footer: {
                        if exercise.id == log.exercises.last?.id {
                            Text("Tap a set to fix it, swipe left to delete it.")
                        }
                    }
            .listRowBackground(Theme.card)
                }
            }
            .themedList()
            .navigationTitle(log.routineName)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editTarget) { target in
                EditLoggedSetSheet(target: target)
            }
        } else {
            ContentUnavailableView("Workout deleted", systemImage: "trash")
        }
    }
}

struct LoggedSetRef: Identifiable {
    let id = UUID()
    let logID: UUID
    let exerciseID: UUID
    let setIndex: Int
    let mode: TrackingMode
    let name: String
    let set: LoggedSet
}

/// Fix a set of a finished workout.
struct EditLoggedSetSheet: View {
    let target: LoggedSetRef

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var first = ""
    @State private var second = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field(target.mode.firstLabel, text: $first, integer: target.mode == .weightReps)
                    field(target.mode.secondLabel, text: $second, integer: false)
                } header: {
                    Text("\(target.name) · Set \(target.setIndex + 1)")
                }
            .listRowBackground(Theme.card)
            }
            .themedList()
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
        }
        .presentationDetents([.height(280)])
        .onAppear {
            let set = target.set
            switch target.mode {
            case .weightReps:
                first = String(set.reps)
                second = Fmt.num(set.weight)
            case .timeDistance:
                first = Fmt.num(set.minutes)
                second = Fmt.num(set.meters)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, integer: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(integer ? .numberPad : .decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(width: 120)
        }
    }

    private func save() {
        var set = target.set
        switch target.mode {
        case .weightReps:
            set.reps = Fmt.parseInt(first)
            set.weight = Fmt.parseDouble(second)
        case .timeDistance:
            set.minutes = Fmt.parseDouble(first)
            set.meters = Fmt.parseDouble(second)
        }
        store.updateLoggedSet(logID: target.logID, exerciseID: target.exerciseID, setIndex: target.setIndex, set: set)
        dismiss()
    }
}

// MARK: - Exercises

struct PerformedExerciseList: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""

    var body: some View {
        let all = store.performedExercises()
        let items = query.trimmed.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(query.trimmed) }
        List {
            if all.isEmpty {
                ContentUnavailableView("No exercise history",
                                       systemImage: "chart.line.uptrend.xyaxis",
                                       description: Text("Exercises you've trained will appear here."))
                    .listRowBackground(Color.clear)
            } else if items.isEmpty {
                ContentUnavailableView.search(text: query)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    NavigationLink {
                        ExerciseHistoryView(exerciseID: item.id, title: item.name)
                    } label: {
                        PerformedExerciseRow(item: item)
                    }
                }
            }
        }
            .themedList()
        .listStyle(.plain)
        .searchable(text: $query, prompt: "Search exercise")
    }
}

struct PerformedExerciseRow: View {
    let item: PerformedExercise
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            ExerciseImageView(exercise: store.exercise(item.id), animated: false)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Text("Last: \(item.lastDate.formatted(date: .abbreviated, time: .omitted)) · \(item.sessions) \(item.sessions == 1 ? "session" : "sessions")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
