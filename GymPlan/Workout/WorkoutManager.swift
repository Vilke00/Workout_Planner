import Foundation
import Observation

/// Runs the active workout: set order, rest timer, alerts, control notification and saving the log.
@Observable
final class WorkoutManager {
    static let shared = WorkoutManager()

    enum Field { case reps, weight, minutes, meters }

    private(set) var session: WorkoutSession?
    var isPresented = false

    @ObservationIgnored private var ticker: Timer?

    private init() {
        session = Persistence.load(WorkoutSession.self, from: "session.json")
    }

    var isActive: Bool { session != nil }

    // MARK: Lifecycle

    /// Called on app launch: continue a workout that was running when the app was closed.
    func restoreIfNeeded() {
        guard session != nil else { return }
        if let end = session?.restEndDate, end <= Date() {
            session?.restEndDate = nil
            persist()
        }
        startTicker()
        if AppSettings.keepAlive { AlertSoundPlayer.shared.startKeepAlive() }
        if let s = session {
            LiveActivityController.shared.restore(routineName: s.routineName,
                                                  startDate: s.startDate,
                                                  state: activityState(s))
        }
        updateControlNotification()
    }

    func start(plan: Plan, routine: Routine, restBetweenExercises: Int) {
        let store = AppStore.shared
        let exercises: [SessionExercise] = routine.exercises.map { item in
            let info = store.exercise(item.exerciseID)
            return SessionExercise(
                exerciseID: item.exerciseID,
                name: info?.name ?? "Exercise",
                primaryMuscles: info?.primaryMuscles ?? [],
                secondaryMuscles: info?.secondaryMuscles ?? [],
                mode: item.mode,
                restSeconds: item.restSeconds,
                supersetWithNext: item.supersetWithNext,
                sets: item.sets.map { SessionSet(reps: $0.reps, weight: $0.weight, minutes: $0.minutes, meters: $0.meters) }
            )
        }
        let steps = WorkoutSession.buildSteps(exercises: exercises, restBetweenExercises: restBetweenExercises)
        guard !exercises.isEmpty, !steps.isEmpty else { return }

        session = WorkoutSession(planID: plan.id,
                                 routineID: routine.id,
                                 planName: plan.name,
                                 routineName: routine.name,
                                 startDate: Date(),
                                 restBetweenExercises: restBetweenExercises,
                                 exercises: exercises,
                                 steps: steps)
        persist()
        startTicker()
        NotificationManager.shared.requestAuthorization()
        if AppSettings.keepAlive { AlertSoundPlayer.shared.startKeepAlive() }
        if let s = session {
            LiveActivityController.shared.start(routineName: s.routineName,
                                                startDate: s.startDate,
                                                state: activityState(s))
        }
        updateControlNotification()
        isPresented = true
    }

    /// Saves completed sets to history and ends the workout.
    func finish() {
        guard let s = session else { return }
        let logged: [LoggedExercise] = s.exercises.compactMap { ex in
            let done = ex.sets.filter { $0.status == .done }
            guard !done.isEmpty else { return nil }
            return LoggedExercise(exerciseID: ex.exerciseID,
                                  name: ex.name,
                                  mode: ex.mode,
                                  sets: done.map { LoggedSet(reps: $0.reps, weight: $0.weight, minutes: $0.minutes, meters: $0.meters) },
                                  primaryMuscles: ex.primaryMuscles,
                                  secondaryMuscles: ex.secondaryMuscles)
        }
        if !logged.isEmpty {
            let log = WorkoutLog(date: s.startDate,
                                 duration: Date().timeIntervalSince(s.startDate),
                                 planName: s.planName,
                                 routineName: s.routineName,
                                 exercises: logged)
            AppStore.shared.addLog(log)
        }
        end()
    }

    func discard() { end() }

    private func end() {
        ticker?.invalidate()
        ticker = nil
        session = nil
        isPresented = false
        Persistence.remove("session.json")
        NotificationManager.shared.clearAll()
        AlertSoundPlayer.shared.stopKeepAlive()
        LiveActivityController.shared.endAll()
    }

    func openFromNotification() {
        if session != nil { isPresented = true }
    }

    // MARK: Sets

    func completeCurrentSet() {
        guard var s = session, let step = s.currentStep else { return }
        s.exercises[step.exerciseIndex].sets[step.setIndex].status = .done
        s.advance()
        let rest = s.isFinished ? 0 : step.restAfter
        if rest > 0 {
            s.restEndDate = Date().addingTimeInterval(TimeInterval(rest))
            s.restDuration = rest
        } else {
            s.restEndDate = nil
            s.restDuration = 0
        }
        session = s
        afterChange(restChanged: true)
    }

    func skipCurrentSet() {
        guard var s = session, let step = s.currentStep else { return }
        s.exercises[step.exerciseIndex].sets[step.setIndex].status = .skipped
        s.advance()
        session = s
        afterChange(restChanged: false)
    }

    /// Changes a value of a set (the current one when indexes are nil).
    func adjust(_ field: Field, by delta: Double, exerciseIndex: Int? = nil, setIndex: Int? = nil) {
        guard var s = session else { return }
        let e: Int
        let i: Int
        if let exerciseIndex, let setIndex {
            e = exerciseIndex
            i = setIndex
        } else if let step = s.currentStep {
            e = step.exerciseIndex
            i = step.setIndex
        } else {
            return
        }
        guard s.exercises.indices.contains(e), s.exercises[e].sets.indices.contains(i) else { return }
        var set = s.exercises[e].sets[i]
        switch field {
        case .reps: set.reps = max(0, set.reps + Int(delta))
        case .weight: set.weight = max(0, set.weight + delta)
        case .minutes: set.minutes = max(0, set.minutes + delta)
        case .meters: set.meters = max(0, set.meters + delta)
        }
        s.exercises[e].sets[i] = set
        session = s
        persist()
        updateControlNotification()
    }

    /// "10x62.5" -> 10 reps, 62.5 kg. For time exercises "5 1000" -> 5 min, 1000 m.
    func applyQuickEdit(_ text: String) {
        guard var s = session, let step = s.currentStep else { return }
        let numbers = Fmt.numbers(in: text)
        guard !numbers.isEmpty else { return }
        var set = s.exercises[step.exerciseIndex].sets[step.setIndex]
        switch s.exercises[step.exerciseIndex].mode {
        case .weightReps:
            set.reps = Int(min(numbers[0], 10_000).rounded())
            if numbers.count > 1 { set.weight = numbers[1] }
        case .timeDistance:
            set.minutes = numbers[0]
            if numbers.count > 1 { set.meters = numbers[1] }
        }
        s.exercises[step.exerciseIndex].sets[step.setIndex] = set
        session = s
        persist()
        updateControlNotification()
    }

    /// Makes the first pending set of an exercise current. Returns false if it has none.
    @discardableResult
    func jump(toExercise exerciseIndex: Int) -> Bool {
        guard var s = session else { return false }
        guard let index = s.steps.indices.first(where: {
            s.steps[$0].exerciseIndex == exerciseIndex && s.isPending(s.steps[$0])
        }) else { return false }
        s.stepIndex = index
        session = s
        persist()
        updateControlNotification()
        return true
    }

    @discardableResult
    func jump(toExercise exerciseIndex: Int, set setIndex: Int) -> Bool {
        guard var s = session else { return false }
        guard let index = s.steps.indices.first(where: {
            s.steps[$0].exerciseIndex == exerciseIndex && s.steps[$0].setIndex == setIndex && s.isPending(s.steps[$0])
        }) else { return false }
        s.stepIndex = index
        session = s
        persist()
        updateControlNotification()
        return true
    }

    // MARK: Rest timer

    func adjustRest(by seconds: Int) {
        guard var s = session, let end = s.restEndDate else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(seconds))
        if newEnd <= Date() {
            s.restEndDate = nil
        } else {
            s.restEndDate = newEnd
            s.restDuration = max(1, s.restDuration + seconds)
        }
        session = s
        afterChange(restChanged: true)
    }

    func skipRest() {
        guard session?.restEndDate != nil else { return }
        session?.restEndDate = nil
        afterChange(restChanged: true)
    }

    /// Starts a rest manually (tap on the timer while it isn't running).
    func startRestNow() {
        guard var s = session else { return }
        var seconds = 60
        if let step = s.currentStep {
            let exerciseRest = s.exercises[step.exerciseIndex].restSeconds
            if exerciseRest > 0 { seconds = exerciseRest }
        }
        s.restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        s.restDuration = seconds
        session = s
        afterChange(restChanged: true)
    }

    // MARK: Lock screen controls

    /// From the Live Activity +/− buttons. value 0 = reps (or minutes), 1 = kg (or meters).
    func adjustFromControls(value: Int, direction: Int) {
        guard let s = session, let step = s.currentStep else { return }
        let sign = direction < 0 ? -1.0 : 1.0
        switch (s.exercises[step.exerciseIndex].mode, value) {
        case (.weightReps, 0): adjust(.reps, by: sign)
        case (.weightReps, _): adjust(.weight, by: sign * AppSettings.weightStep)
        case (.timeDistance, 0): adjust(.minutes, by: sign * 0.5)
        case (.timeDistance, _): adjust(.meters, by: sign * 50)
        }
    }

    func handleNotificationAction(_ id: String, text: String?) {
        guard let s = session else { return }
        switch id {
        case NotificationManager.Action.done.rawValue:
            completeCurrentSet()
        case NotificationManager.Action.skip.rawValue:
            skipCurrentSet()
        case NotificationManager.Action.minus.rawValue:
            if let step = s.currentStep, s.exercises[step.exerciseIndex].mode == .timeDistance {
                adjust(.minutes, by: -1)
            } else {
                adjust(.reps, by: -1)
            }
        case NotificationManager.Action.edit.rawValue:
            if let text { applyQuickEdit(text) }
        default:
            break
        }
    }

    // MARK: Internals

    private func afterChange(restChanged: Bool) {
        persist()
        if restChanged {
            NotificationManager.shared.clearRestEnd()
            if let end = session?.restEndDate {
                let content = restEndContent()
                // Scheduled slightly late; if the app is awake it cancels this and beeps itself.
                NotificationManager.shared.scheduleRestEnd(at: end.addingTimeInterval(1.5),
                                                           title: content.title,
                                                           body: content.body,
                                                           category: content.category)
            }
        }
        updateControlNotification()
    }

    private func persist() {
        if let session {
            Persistence.save(session, to: "session.json")
        } else {
            Persistence.remove("session.json")
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard let end = session?.restEndDate, Date() >= end else { return }
        restFinished()
    }

    private func restFinished() {
        session?.restEndDate = nil
        persist()
        NotificationManager.shared.cancelPendingRestEnd()
        AlertSoundPlayer.shared.playRestEnd(sound: AppSettings.restSound, vibrate: AppSettings.restVibrate)
        let content = restEndContent()
        NotificationManager.shared.showRestEndNow(title: content.title, body: content.body, category: content.category)
        updateControlNotification()
    }

    private func restEndContent() -> (title: String, body: String, category: NotificationManager.Category?) {
        guard let s = session, let step = s.currentStep else {
            return ("Rest is over", "Time for the next set.", nil)
        }
        let ex = s.exercises[step.exerciseIndex]
        let set = ex.sets[step.setIndex]
        let body = "Next: \(ex.name) · Set \(step.setIndex + 1)/\(ex.sets.count) · \(Fmt.setValue(set, mode: ex.mode))"
        let category: NotificationManager.Category = ex.mode == .weightReps ? .weight : .time
        return ("Rest is over", body, category)
    }

    private func activityState(_ s: WorkoutSession) -> WorkoutActivityAttributes.ContentState {
        var restStart: Date? = nil
        if let end = s.restEndDate {
            restStart = end.addingTimeInterval(-TimeInterval(max(s.restDuration, 1)))
        }
        guard let step = s.currentStep else {
            return WorkoutActivityAttributes.ContentState(exerciseName: s.routineName,
                                                          setNumber: 0, setCount: 0, isTime: false,
                                                          firstValue: "", secondValue: "",
                                                          restStart: nil, restEnd: nil, finished: true)
        }
        let ex = s.exercises[step.exerciseIndex]
        let set = ex.sets[step.setIndex]
        let isTime = ex.mode == .timeDistance
        return WorkoutActivityAttributes.ContentState(exerciseName: ex.name,
                                                      setNumber: step.setIndex + 1,
                                                      setCount: ex.sets.count,
                                                      isTime: isTime,
                                                      firstValue: isTime ? Fmt.num(set.minutes) : String(set.reps),
                                                      secondValue: isTime ? Fmt.num(set.meters) : Fmt.num(set.weight),
                                                      restStart: restStart,
                                                      restEnd: s.restEndDate,
                                                      finished: false)
    }

    /// Live Activity when it runs (normal install), otherwise the control notification (LiveContainer).
    private func updateControlNotification() {
        guard let s = session else {
            NotificationManager.shared.removeControl()
            return
        }
        if LiveActivityController.shared.isRunning {
            LiveActivityController.shared.update(activityState(s))
            NotificationManager.shared.removeControl()
            return
        }
        guard let step = s.currentStep else {
            NotificationManager.shared.postControl(title: "All sets done 💪",
                                                   subtitle: s.routineName,
                                                   body: "Open the app and tap Finish to save the workout.",
                                                   category: nil)
            return
        }
        let ex = s.exercises[step.exerciseIndex]
        let set = ex.sets[step.setIndex]
        let subtitle = "Set \(step.setIndex + 1)/\(ex.sets.count) · \(Fmt.setValue(set, mode: ex.mode))"
        let category: NotificationManager.Category = ex.mode == .weightReps ? .weight : .time
        var body = "Started \(Fmt.time(s.startDate))"
        if let end = s.restEndDate {
            body = "Rest until \(Fmt.time(end)) · " + body
        }
        NotificationManager.shared.postControl(title: ex.name,
                                               subtitle: subtitle,
                                               body: body,
                                               category: category)
    }
}
