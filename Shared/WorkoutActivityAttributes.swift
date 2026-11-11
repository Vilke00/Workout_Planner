import ActivityKit
import Foundation

/// Data shown on the lock screen / Dynamic Island card during a workout.
/// Compiled into both the app and the widget extension.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setNumber: Int
        var setCount: Int
        var isTime: Bool
        /// Reps (or minutes for time exercises), already formatted.
        var firstValue: String
        /// Kg (or meters for time exercises), already formatted.
        var secondValue: String
        var restStart: Date?
        var restEnd: Date?
        var finished: Bool
        /// Rep target, e.g. "8–12 reps" or "AMRAP" (display only).
        var target: String?

        var firstUnit: String { isTime ? "min" : "reps" }
        var secondUnit: String { isTime ? "m" : "kg" }
    }

    var routineName: String
    var startDate: Date
}
