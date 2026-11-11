import Foundation

/// Double progression inside a rep range.
///
/// - Reached the top of the range (e.g. 12 of 8–12): next time reps go back to the bottom (8)
///   and the weight goes up to what the last set predicts for that many reps (Epley 1RM),
///   rounded to the weight step and always heavier than last time.
/// - Inside the range: same weight, one more rep.
/// - Below the range: same weight, aim for the bottom of the range.
/// - No range: the weight used is remembered for next time.
enum Progression {
    static func apply(to option: inout ExerciseOption, performed ex: SessionExercise, step: Double) -> String? {
        guard option.mode == .weightReps, ex.mode == .weightReps else { return nil }
        let before = option.sets
        let range = option.target.range

        for i in option.sets.indices {
            guard ex.sets.indices.contains(i), ex.sets[i].status == .done else { continue }
            let done = ex.sets[i]
            var next = option.sets[i]
            if let range {
                let reps = done.reps
                let weight = done.weight
                if reps >= range.upperBound {
                    if weight > 0 {
                        next.weight = nextWeight(from: weight, reps: reps, targetReps: range.lowerBound, step: step)
                        next.reps = range.lowerBound
                    } else {
                        // Bodyweight: keep adding reps.
                        next.weight = 0
                        next.reps = reps + 1
                    }
                } else if reps >= range.lowerBound {
                    next.weight = weight
                    next.reps = reps + 1
                } else {
                    next.weight = weight
                    next.reps = range.lowerBound
                }
            } else if done.weight > 0 {
                next.weight = done.weight
            }
            option.sets[i] = next
        }

        guard option.sets != before else { return nil }
        return "\(ex.name): \(Fmt.setsSummary(option.sets, mode: .weightReps))"
    }

    /// Weight for `targetReps` that matches `weight × reps` (Epley), rounded to `step`, always > weight.
    static func nextWeight(from weight: Double, reps: Int, targetReps: Int, step: Double) -> Double {
        let increment = step > 0 ? step : 2.5
        let oneRepMax = weight * (1 + Double(reps) / 30)
        let raw = oneRepMax / (1 + Double(max(targetReps, 1)) / 30)
        var rounded = (raw / increment).rounded() * increment
        if rounded <= weight { rounded = weight + increment }
        return rounded
    }
}
