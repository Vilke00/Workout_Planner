import Foundation

// MARK: - Tolerant decoding helper
// Every model decodes missing / unknown fields with a default, so adding new
// fields in later versions never wipes the user's saved data.

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

// MARK: - Tracking mode

enum TrackingMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case weightReps
    case timeDistance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weightReps: return "Weights / Bodyweight"
        case .timeDistance: return "Time / Distance"
        }
    }

    var firstLabel: String { self == .weightReps ? "Reps" : "Time (min)" }
    var secondLabel: String { self == .weightReps ? "Kg" : "Meters" }
}

// MARK: - Plan / Routine / Exercise in routine

struct SetTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var reps: Int
    var weight: Double
    var minutes: Double
    var meters: Double

    init(id: UUID = UUID(), reps: Int = 10, weight: Double = 0, minutes: Double = 0, meters: Double = 0) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.minutes = minutes
        self.meters = meters
    }

    enum CodingKeys: String, CodingKey { case id, reps, weight, minutes, meters }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        reps = c.value(.reps, default: 0)
        weight = c.value(.weight, default: 0)
        minutes = c.value(.minutes, default: 0)
        meters = c.value(.meters, default: 0)
    }
}

/// Target reps for an exercise: a range like 8–12, or AMRAP (as many reps as possible).
struct RepTarget: Codable, Hashable {
    var min: Int?
    var max: Int?
    var amrap: Bool

    init(min: Int? = nil, max: Int? = nil, amrap: Bool = false) {
        self.min = min
        self.max = max
        self.amrap = amrap
    }

    static let empty = RepTarget()

    enum CodingKeys: String, CodingKey { case min, max, amrap }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        min = c.value(.min, default: Int?.none)
        max = c.value(.max, default: Int?.none)
        amrap = c.value(.amrap, default: false)
    }

    var isEmpty: Bool { !amrap && min == nil && max == nil }

    /// Lower and upper bound when both exist (a single number counts as both).
    var range: ClosedRange<Int>? {
        guard !amrap else { return nil }
        switch (min, max) {
        case let (lo?, hi?): return Swift.min(lo, hi)...Swift.max(lo, hi)
        case let (lo?, nil): return lo...lo
        case let (nil, hi?): return hi...hi
        default: return nil
        }
    }

    /// "8–12 reps", "10 reps", "AMRAP" or nil.
    var text: String? {
        if amrap { return "AMRAP" }
        guard let r = range else { return nil }
        return r.lowerBound == r.upperBound ? "\(r.lowerBound) reps" : "\(r.lowerBound)–\(r.upperBound) reps"
    }
}

/// An alternative exercise for a slot in a routine ("Bench press OR Dips").
/// It keeps its own sets and rep target, so switching back and forth keeps both.
struct ExerciseOption: Identifiable, Codable, Hashable {
    var id: UUID
    var exerciseID: String
    var mode: TrackingMode
    var sets: [SetTemplate]
    var target: RepTarget

    init(id: UUID = UUID(), exerciseID: String, mode: TrackingMode = .weightReps,
         sets: [SetTemplate] = [SetTemplate()], target: RepTarget = .empty) {
        self.id = id
        self.exerciseID = exerciseID
        self.mode = mode
        self.sets = sets
        self.target = target
    }

    enum CodingKeys: String, CodingKey { case id, exerciseID, mode, sets, target }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        exerciseID = c.value(.exerciseID, default: "")
        mode = c.value(.mode, default: TrackingMode.weightReps)
        sets = c.value(.sets, default: [SetTemplate]())
        target = c.value(.target, default: RepTarget.empty)
    }
}

struct RoutineExercise: Identifiable, Codable, Hashable {
    var id: UUID
    var exerciseID: String
    var mode: TrackingMode
    var sets: [SetTemplate]
    var restSeconds: Int
    /// When true this card is chained (superset) with the card below it.
    var supersetWithNext: Bool
    var target: RepTarget
    /// Other exercises that can be done instead of this one.
    var alternatives: [ExerciseOption]

    init(id: UUID = UUID(), exerciseID: String, mode: TrackingMode = .weightReps,
         sets: [SetTemplate] = [SetTemplate()], restSeconds: Int = 0, supersetWithNext: Bool = false,
         target: RepTarget = .empty, alternatives: [ExerciseOption] = []) {
        self.id = id
        self.exerciseID = exerciseID
        self.mode = mode
        self.sets = sets
        self.restSeconds = restSeconds
        self.supersetWithNext = supersetWithNext
        self.target = target
        self.alternatives = alternatives
    }

    enum CodingKeys: String, CodingKey {
        case id, exerciseID, mode, sets, restSeconds, supersetWithNext, target, alternatives
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        exerciseID = c.value(.exerciseID, default: "")
        mode = c.value(.mode, default: TrackingMode.weightReps)
        sets = c.value(.sets, default: [SetTemplate]())
        restSeconds = c.value(.restSeconds, default: 0)
        supersetWithNext = c.value(.supersetWithNext, default: false)
        target = c.value(.target, default: RepTarget.empty)
        alternatives = c.value(.alternatives, default: [ExerciseOption]())
    }

    /// The exercise currently chosen for this slot, as an option.
    var activeOption: ExerciseOption {
        ExerciseOption(id: id, exerciseID: exerciseID, mode: mode, sets: sets, target: target)
    }

    /// Makes an alternative the active exercise; the current one becomes an alternative.
    mutating func switchTo(alternative optionID: UUID) {
        guard let index = alternatives.firstIndex(where: { $0.id == optionID }) else { return }
        let chosen = alternatives[index]
        var previous = activeOption
        previous.id = chosen.id
        alternatives[index] = previous
        exerciseID = chosen.exerciseID
        mode = chosen.mode
        sets = chosen.sets
        target = chosen.target
    }

    func duplicated() -> RoutineExercise {
        var copy = self
        copy.id = UUID()
        copy.sets = sets.map { set in
            var s = set
            s.id = UUID()
            return s
        }
        copy.alternatives = alternatives.map { option in
            var o = option
            o.id = UUID()
            return o
        }
        return copy
    }
}

struct Routine: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var exercises: [RoutineExercise]

    init(id: UUID = UUID(), name: String, exercises: [RoutineExercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }

    enum CodingKeys: String, CodingKey { case id, name, exercises }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        name = c.value(.name, default: "Routine")
        exercises = c.value(.exercises, default: [RoutineExercise]())
    }

    func duplicated(name newName: String? = nil) -> Routine {
        Routine(name: newName ?? name, exercises: exercises.map { $0.duplicated() })
    }
}

struct Plan: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var routines: [Routine]

    init(id: UUID = UUID(), name: String, routines: [Routine] = []) {
        self.id = id
        self.name = name
        self.routines = routines
    }

    enum CodingKeys: String, CodingKey { case id, name, routines }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        name = c.value(.name, default: "Plan")
        routines = c.value(.routines, default: [Routine]())
    }

    func duplicated(name newName: String) -> Plan {
        Plan(name: newName, routines: routines.map { $0.duplicated() })
    }
}

// MARK: - Workout history

struct LoggedSet: Codable, Hashable {
    var reps: Int
    var weight: Double
    var minutes: Double
    var meters: Double

    init(reps: Int, weight: Double, minutes: Double, meters: Double) {
        self.reps = reps
        self.weight = weight
        self.minutes = minutes
        self.meters = meters
    }

    enum CodingKeys: String, CodingKey { case reps, weight, minutes, meters }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reps = c.value(.reps, default: 0)
        weight = c.value(.weight, default: 0)
        minutes = c.value(.minutes, default: 0)
        meters = c.value(.meters, default: 0)
    }
}

struct LoggedExercise: Identifiable, Codable, Hashable {
    var id: UUID
    var exerciseID: String
    var name: String
    var mode: TrackingMode
    var sets: [LoggedSet]
    var primaryMuscles: [String]
    var secondaryMuscles: [String]

    init(id: UUID = UUID(), exerciseID: String, name: String, mode: TrackingMode, sets: [LoggedSet],
         primaryMuscles: [String], secondaryMuscles: [String]) {
        self.id = id
        self.exerciseID = exerciseID
        self.name = name
        self.mode = mode
        self.sets = sets
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
    }

    enum CodingKeys: String, CodingKey { case id, exerciseID, name, mode, sets, primaryMuscles, secondaryMuscles }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        exerciseID = c.value(.exerciseID, default: "")
        name = c.value(.name, default: "Exercise")
        mode = c.value(.mode, default: TrackingMode.weightReps)
        sets = c.value(.sets, default: [LoggedSet]())
        primaryMuscles = c.value(.primaryMuscles, default: [String]())
        secondaryMuscles = c.value(.secondaryMuscles, default: [String]())
    }
}

struct WorkoutLog: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var planName: String
    var routineName: String
    var exercises: [LoggedExercise]

    init(id: UUID = UUID(), date: Date, duration: TimeInterval, planName: String, routineName: String,
         exercises: [LoggedExercise]) {
        self.id = id
        self.date = date
        self.duration = duration
        self.planName = planName
        self.routineName = routineName
        self.exercises = exercises
    }

    enum CodingKeys: String, CodingKey { case id, date, duration, planName, routineName, exercises }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, default: UUID())
        date = c.value(.date, default: Date())
        duration = c.value(.duration, default: 0)
        planName = c.value(.planName, default: "")
        routineName = c.value(.routineName, default: "Workout")
        exercises = c.value(.exercises, default: [LoggedExercise]())
    }

    var primaryMuscles: Set<String> {
        Set(exercises.flatMap { $0.primaryMuscles.map { $0.lowercased() } })
    }

    var secondaryMuscles: Set<String> {
        Set(exercises.flatMap { $0.secondaryMuscles.map { $0.lowercased() } }).subtracting(primaryMuscles)
    }

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    var volume: Double {
        exercises.reduce(0) { total, ex in
            guard ex.mode == .weightReps else { return total }
            return total + ex.sets.reduce(0) { $0 + Double($1.reps) * $1.weight }
        }
    }
}

// MARK: - Active workout session

enum SetStatus: String, Codable {
    case pending, done, skipped
}

struct SessionSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var reps: Int
    var weight: Double
    var minutes: Double
    var meters: Double
    var status: SetStatus = .pending
}

struct SessionExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Slot in the routine this came from (used for progression). Optional for old saved sessions.
    var routineExerciseID: UUID?
    var target: RepTarget?
    var exerciseID: String
    var name: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var mode: TrackingMode
    var restSeconds: Int
    var supersetWithNext: Bool
    var sets: [SessionSet]
}

struct WorkoutStep: Codable, Hashable {
    var exerciseIndex: Int
    var setIndex: Int
    /// Rest (seconds) that starts after this set is completed.
    var restAfter: Int
}

struct WorkoutSession: Codable {
    var id = UUID()
    var planID: UUID
    var routineID: UUID
    var planName: String
    var routineName: String
    var startDate: Date
    var restBetweenExercises: Int
    var exercises: [SessionExercise]
    var steps: [WorkoutStep]
    var stepIndex: Int = 0
    var restEndDate: Date? = nil
    var restDuration: Int = 0

    var currentStep: WorkoutStep? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }

    var isFinished: Bool { currentStep == nil }

    func isPending(_ step: WorkoutStep) -> Bool {
        guard exercises.indices.contains(step.exerciseIndex),
              exercises[step.exerciseIndex].sets.indices.contains(step.setIndex) else { return false }
        return exercises[step.exerciseIndex].sets[step.setIndex].status == .pending
    }

    func isExerciseComplete(_ index: Int) -> Bool {
        guard exercises.indices.contains(index) else { return false }
        return !exercises[index].sets.contains { $0.status == .pending }
    }

    func isInSuperset(_ index: Int) -> Bool {
        guard exercises.indices.contains(index) else { return false }
        if exercises[index].supersetWithNext && index < exercises.count - 1 { return true }
        return index > 0 && exercises[index - 1].supersetWithNext
    }

    /// Moves to the next pending set (after the current one, then wrapping around).
    mutating func advance() {
        let current = stepIndex
        if let next = steps.indices.first(where: { $0 > current && isPending(steps[$0]) }) {
            stepIndex = next
        } else if let any = steps.indices.first(where: { isPending(steps[$0]) }) {
            stepIndex = any
        } else {
            stepIndex = steps.count
        }
    }

    /// Order of sets. Exercises chained as a superset alternate set by set:
    /// A1 → B1 → rest → A2 → B2 → rest ...
    static func buildSteps(exercises: [SessionExercise], restBetweenExercises: Int) -> [WorkoutStep] {
        var blocks: [[Int]] = []
        var current: [Int] = []
        for i in exercises.indices {
            current.append(i)
            if !exercises[i].supersetWithNext || i == exercises.count - 1 {
                blocks.append(current)
                current = []
            }
        }

        var steps: [WorkoutStep] = []
        for (blockNumber, block) in blocks.enumerated() {
            let maxSets = block.map { exercises[$0].sets.count }.max() ?? 0
            let blockRest = block.map { exercises[$0].restSeconds }.max() ?? 0
            var blockSteps: [WorkoutStep] = []
            for setIndex in 0..<maxSets {
                let inRound = block.filter { setIndex < exercises[$0].sets.count }
                for (k, exerciseIndex) in inRound.enumerated() {
                    let isLastInRound = k == inRound.count - 1
                    let rest = isLastInRound ? (block.count > 1 ? blockRest : exercises[exerciseIndex].restSeconds) : 0
                    blockSteps.append(WorkoutStep(exerciseIndex: exerciseIndex, setIndex: setIndex, restAfter: rest))
                }
            }
            if !blockSteps.isEmpty {
                let isLastBlock = blockNumber == blocks.count - 1
                blockSteps[blockSteps.count - 1].restAfter = isLastBlock ? 0 : restBetweenExercises
            }
            steps.append(contentsOf: blockSteps)
        }
        return steps
    }
}
