import Foundation
import Observation
import SwiftUI

struct HistoryEntry: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let mode: TrackingMode
    let sets: [LoggedSet]
}

struct PerformedExercise: Identifiable, Hashable {
    let id: String
    let name: String
    let lastDate: Date
    let sessions: Int
}

struct ImportResult {
    var planName: String = ""
    var routinesCreated: Int = 0
    var exercisesAdded: Int = 0
    var customCreated: [String] = []
}

@Observable
final class AppStore {
    static let shared = AppStore()

    private(set) var plans: [Plan] = []
    private(set) var selectedPlanID: UUID?
    private(set) var logs: [WorkoutLog] = []
    private(set) var customExercises: [Exercise] = []
    private(set) var libraryExercises: [Exercise] = []
    private(set) var allExercises: [Exercise] = []
    private(set) var muscleOptions: [String] = []
    private(set) var equipmentOptions: [String] = []
    private var exerciseIndex: [String: Exercise] = [:]

    private init() {
        libraryExercises = Self.loadLibrary()
        customExercises = Persistence.load([Exercise].self, from: "custom_exercises.json") ?? []
        logs = Persistence.load([WorkoutLog].self, from: "logs.json") ?? []
        let hadPlansFile = Persistence.exists("plans.json")
        plans = Persistence.load([Plan].self, from: "plans.json") ?? []
        if let raw = UserDefaults.standard.string(forKey: AppSettings.Keys.selectedPlan) {
            selectedPlanID = UUID(uuidString: raw)
        }
        rebuildExerciseIndex()
        if plans.isEmpty && !hadPlansFile { seed() }
        if selectedPlan == nil { selectPlan(plans.first?.id) }
    }

    // MARK: - Library

    private static func loadLibrary() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([Exercise].self, from: data)
        } catch {
            print("Exercise library decode failed: \(error)")
            return []
        }
    }

    private func rebuildExerciseIndex() {
        let all = (libraryExercises + customExercises).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        allExercises = all
        exerciseIndex = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        muscleOptions = Array(Set(all.flatMap { $0.primaryMuscles.map { $0.lowercased() } })).sorted()
        equipmentOptions = Array(Set(all.flatMap { $0.equipmentTags })).sorted()
    }

    func exercise(_ id: String) -> Exercise? { exerciseIndex[id] }

    // MARK: - Plans

    var selectedPlan: Plan? {
        guard let id = selectedPlanID else { return nil }
        return plan(id)
    }

    func plan(_ id: UUID) -> Plan? { plans.first { $0.id == id } }

    func routine(planID: UUID, routineID: UUID) -> Routine? {
        plan(planID)?.routines.first { $0.id == routineID }
    }

    func selectPlan(_ id: UUID?) {
        selectedPlanID = id
        UserDefaults.standard.set(id?.uuidString, forKey: AppSettings.Keys.selectedPlan)
    }

    @discardableResult
    func addPlan(name: String) -> UUID {
        let plan = Plan(name: name, routines: [Routine(name: "Day 1")])
        plans.append(plan)
        selectPlan(plan.id)
        savePlans()
        return plan.id
    }

    func renamePlan(_ id: UUID, to name: String) {
        updatePlan(id) { $0.name = name }
    }

    func duplicatePlan(_ id: UUID) {
        guard let index = plans.firstIndex(where: { $0.id == id }) else { return }
        let copy = plans[index].duplicated(name: plans[index].name + " Copy")
        plans.insert(copy, at: index + 1)
        selectPlan(copy.id)
        savePlans()
    }

    func deletePlan(_ id: UUID) {
        plans.removeAll { $0.id == id }
        if selectedPlanID == id { selectPlan(plans.first?.id) }
        savePlans()
    }

    func updatePlan(_ id: UUID, _ change: (inout Plan) -> Void) {
        guard let index = plans.firstIndex(where: { $0.id == id }) else { return }
        change(&plans[index])
        savePlans()
    }

    // MARK: - Routines

    @discardableResult
    func addRoutine(planID: UUID, name: String) -> UUID? {
        let routine = Routine(name: name)
        var added = false
        updatePlan(planID) { plan in
            plan.routines.append(routine)
            added = true
        }
        return added ? routine.id : nil
    }

    func renameRoutine(planID: UUID, routineID: UUID, to name: String) {
        updateRoutine(planID: planID, routineID: routineID) { $0.name = name }
    }

    func duplicateRoutine(planID: UUID, routineID: UUID) {
        updatePlan(planID) { plan in
            guard let index = plan.routines.firstIndex(where: { $0.id == routineID }) else { return }
            let copy = plan.routines[index].duplicated(name: plan.routines[index].name + " Copy")
            plan.routines.insert(copy, at: index + 1)
        }
    }

    func deleteRoutine(planID: UUID, routineID: UUID) {
        updatePlan(planID) { plan in
            plan.routines.removeAll { $0.id == routineID }
        }
    }

    func moveRoutines(planID: UUID, from source: IndexSet, to destination: Int) {
        updatePlan(planID) { plan in
            plan.routines.move(fromOffsets: source, toOffset: destination)
        }
    }

    func updateRoutine(planID: UUID, routineID: UUID, _ change: (inout Routine) -> Void) {
        guard let planIndex = plans.firstIndex(where: { $0.id == planID }),
              let routineIndex = plans[planIndex].routines.firstIndex(where: { $0.id == routineID }) else { return }
        change(&plans[planIndex].routines[routineIndex])
        savePlans()
    }

    // MARK: - Exercises in a routine

    func addExercise(_ exercise: RoutineExercise, planID: UUID, routineID: UUID) {
        updateRoutine(planID: planID, routineID: routineID) { routine in
            routine.exercises.append(exercise)
        }
    }

    func updateExercise(_ exercise: RoutineExercise, planID: UUID, routineID: UUID) {
        updateRoutine(planID: planID, routineID: routineID) { routine in
            if let index = routine.exercises.firstIndex(where: { $0.id == exercise.id }) {
                routine.exercises[index] = exercise
            }
        }
    }

    func deleteExercise(_ id: UUID, planID: UUID, routineID: UUID) {
        updateRoutine(planID: planID, routineID: routineID) { routine in
            routine.exercises.removeAll { $0.id == id }
            if !routine.exercises.isEmpty {
                routine.exercises[routine.exercises.count - 1].supersetWithNext = false
            }
        }
    }

    func setExercises(_ exercises: [RoutineExercise], planID: UUID, routineID: UUID) {
        var list = exercises
        if !list.isEmpty { list[list.count - 1].supersetWithNext = false }
        updateRoutine(planID: planID, routineID: routineID) { routine in
            routine.exercises = list
        }
    }

    // MARK: - Logs / history

    func addLog(_ log: WorkoutLog) {
        logs.insert(log, at: 0)
        logs.sort { $0.date > $1.date }
        saveLogs()
    }

    func deleteLog(_ id: UUID) {
        logs.removeAll { $0.id == id }
        saveLogs()
    }

    func clearLogs() {
        logs.removeAll()
        saveLogs()
    }

    /// Sessions for one exercise, newest first. With `onlyChanges` only the sessions
    /// where the numbers differ from the previous session are kept.
    func history(for exerciseID: String, onlyChanges: Bool) -> [HistoryEntry] {
        let chronological: [HistoryEntry] = logs.sorted { $0.date < $1.date }.compactMap { log in
            guard let ex = log.exercises.first(where: { $0.exerciseID == exerciseID }), !ex.sets.isEmpty else {
                return nil
            }
            return HistoryEntry(id: log.id, date: log.date, mode: ex.mode, sets: ex.sets)
        }
        guard onlyChanges else { return Array(chronological.reversed()) }
        var result: [HistoryEntry] = []
        var previous: [LoggedSet]? = nil
        for entry in chronological where entry.sets != previous {
            result.append(entry)
            previous = entry.sets
        }
        return Array(result.reversed())
    }

    func performedExercises() -> [PerformedExercise] {
        var seen: [String: PerformedExercise] = [:]
        var order: [String] = []
        for log in logs.sorted(by: { $0.date > $1.date }) {
            for ex in log.exercises where !ex.sets.isEmpty {
                if let existing = seen[ex.exerciseID] {
                    seen[ex.exerciseID] = PerformedExercise(id: existing.id, name: existing.name,
                                                            lastDate: existing.lastDate, sessions: existing.sessions + 1)
                } else {
                    let name = exercise(ex.exerciseID)?.name ?? ex.name
                    seen[ex.exerciseID] = PerformedExercise(id: ex.exerciseID, name: name, lastDate: log.date, sessions: 1)
                    order.append(ex.exerciseID)
                }
            }
        }
        return order.compactMap { seen[$0] }
    }

    // MARK: - Import

    func applyImport(_ routines: [ImportedRoutine], planID: UUID?, newPlanName: String) -> ImportResult {
        var result = ImportResult()
        let targetID: UUID
        if let planID, plan(planID) != nil {
            targetID = planID
        } else {
            let name = newPlanName.trimmed.isEmpty ? "Imported Plan" : newPlanName.trimmed
            let newPlan = Plan(name: name)
            plans.append(newPlan)
            targetID = newPlan.id
        }
        guard let planIndex = plans.firstIndex(where: { $0.id == targetID }) else { return result }
        result.planName = plans[planIndex].name

        var lookup = Dictionary(allExercises.map { (EquipmentCatalog.normalize($0.name), $0.id) },
                                uniquingKeysWith: { first, _ in first })
        var newCustom: [Exercise] = []

        for imported in routines {
            let routineIndex: Int
            if let existing = plans[planIndex].routines.firstIndex(where: {
                $0.name.caseInsensitiveCompare(imported.name) == .orderedSame
            }) {
                routineIndex = existing
            } else {
                plans[planIndex].routines.append(Routine(name: imported.name))
                routineIndex = plans[planIndex].routines.count - 1
                result.routinesCreated += 1
            }

            for item in imported.exercises {
                let key = EquipmentCatalog.normalize(item.name)
                let exerciseID: String
                if let found = lookup[key] {
                    exerciseID = found
                } else {
                    let custom = Exercise.custom(name: item.name)
                    newCustom.append(custom)
                    lookup[key] = custom.id
                    exerciseID = custom.id
                    result.customCreated.append(item.name)
                }
                let routineExercise = RoutineExercise(exerciseID: exerciseID, mode: item.mode,
                                                      sets: item.sets, restSeconds: item.restSeconds,
                                                      supersetWithNext: item.supersetWithNext)
                plans[planIndex].routines[routineIndex].exercises.append(routineExercise)
                result.exercisesAdded += 1
            }
            // The last exercise of a routine can't be chained to anything.
            if let last = plans[planIndex].routines[routineIndex].exercises.indices.last {
                plans[planIndex].routines[routineIndex].exercises[last].supersetWithNext = false
            }
        }

        if !newCustom.isEmpty {
            customExercises.append(contentsOf: newCustom)
            Persistence.save(customExercises, to: "custom_exercises.json")
            rebuildExerciseIndex()
        }
        selectPlan(targetID)
        savePlans()
        return result
    }

    // MARK: - Saving

    private func savePlans() { Persistence.save(plans, to: "plans.json") }
    private func saveLogs() { Persistence.save(logs, to: "logs.json") }

    private func seed() {
        let names = ["Daily", "Full Body", "Upper", "Lower"]
        let plan = Plan(name: "Solo Leveling", routines: names.map { Routine(name: $0) })
        plans = [plan]
        selectPlan(plan.id)
        savePlans()
    }
}
