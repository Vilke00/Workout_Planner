import SwiftUI

/// Full-screen workout: total timer, exercise line, image, sets, and X / rest timer / Done bar.
struct ActiveWorkoutView: View {
    @Environment(WorkoutManager.self) private var workout
    @Environment(AppStore.self) private var store
    @AppStorage(AppSettings.Keys.weightStep) private var weightStep = 2.5

    @State private var viewedExercise: Int?
    @State private var historyTarget: SessionExercise?
    @State private var showEndOptions = false
    @State private var doneCount = 0

    var body: some View {
        Group {
            if let session = workout.session, !session.exercises.isEmpty {
                content(session)
            } else {
                Color(uiColor: .systemBackground)
                    .onAppear { workout.isPresented = false }
            }
        }
        .sheet(item: $historyTarget) { item in
            NavigationStack {
                ExerciseHistoryView(exerciseID: item.exerciseID, title: item.name)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Close") { historyTarget = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("End workout?", isPresented: $showEndOptions, titleVisibility: .visible) {
            Button("Finish & Save") { workout.finish() }
            Button("Discard Workout", role: .destructive) { workout.discard() }
            Button("Cancel", role: .cancel) {}
        }
        .sensoryFeedback(.success, trigger: doneCount)
        .onChange(of: workout.session?.stepIndex) { _, _ in
            viewedExercise = nil
        }
    }

    // MARK: Layout

    @ViewBuilder
    private func content(_ s: WorkoutSession) -> some View {
        let currentIndex = s.currentStep?.exerciseIndex ?? (s.exercises.count - 1)
        let shownIndex = min(max(viewedExercise ?? currentIndex, 0), s.exercises.count - 1)
        let exercise = s.exercises[shownIndex]

        VStack(spacing: 0) {
            topBar(s)

            ExerciseProgressLine(count: s.exercises.count,
                                 current: shownIndex,
                                 completed: s.exercises.indices.map { s.isExerciseComplete($0) }) { index in
                if workout.jump(toExercise: index) {
                    viewedExercise = nil
                } else {
                    viewedExercise = index
                }
            }
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ExerciseImageView(exercise: store.exercise(exercise.exerciseID), animated: true, fill: false)
                        .frame(maxWidth: .infinity)
                        .frame(height: 230)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    titleRow(exercise, inSuperset: s.isInSuperset(shownIndex))

                    setsList(s, exerciseIndex: shownIndex)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }

            bottomBar(s)
        }
        .background(Theme.background)
    }

    private func topBar(_ s: WorkoutSession) -> some View {
        HStack {
            Button {
                workout.isPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.card))
            }
            .foregroundStyle(.primary)

            Spacer()

            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Fmt.clock(context.date.timeIntervalSince(s.startDate)))
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                }
                Text(s.routineName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showEndOptions = true
            } label: {
                Image(systemName: "flag.checkered")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.card))
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func titleRow(_ exercise: SessionExercise, inSuperset: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.title2.bold())
                Text(exercise.primaryMuscles.map(Fmt.title).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if inSuperset {
                    Label("Superset", systemImage: "link")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer()
            Button {
                historyTarget = exercise
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.card))
            }
            .foregroundStyle(Theme.accent)
        }
    }

    private func setsList(_ s: WorkoutSession, exerciseIndex: Int) -> some View {
        let exercise = s.exercises[exerciseIndex]
        return VStack(spacing: 8) {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                ActiveSetRow(number: index + 1,
                             set: set,
                             mode: exercise.mode,
                             isCurrent: s.currentStep?.exerciseIndex == exerciseIndex && s.currentStep?.setIndex == index,
                             weightStep: weightStep,
                             onAdjust: { field, delta in
                                 workout.adjust(field, by: delta, exerciseIndex: exerciseIndex, setIndex: index)
                             },
                             onSelect: {
                                 _ = workout.jump(toExercise: exerciseIndex, set: index)
                             })
            }
        }
    }

    @ViewBuilder
    private func bottomBar(_ s: WorkoutSession) -> some View {
        VStack(spacing: 0) {
            Divider()
            if s.isFinished {
                Button {
                    workout.finish()
                } label: {
                    Text("Finish")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Theme.accent))
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 14) {
                    Button {
                        workout.skipCurrentSet()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.bold))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Theme.card))
                    }
                    .foregroundStyle(.primary)

                    RestTimerControl(session: s)
                        .frame(maxWidth: .infinity)

                    Button {
                        workout.completeCurrentSet()
                        doneCount += 1
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 56)
                            .background(Capsule().fill(Theme.accent))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
        }
        .background(.bar)
    }
}

// MARK: - Exercise line (1 — 2 — 3 ...)

struct ExerciseProgressLine: View {
    let count: Int
    let current: Int
    let completed: [Bool]
    let onTap: (Int) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line
                .padding(.horizontal)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    line
                        .padding(.horizontal)
                }
                .onAppear { proxy.scrollTo(current, anchor: .center) }
                .onChange(of: current) { _, value in
                    withAnimation { proxy.scrollTo(value, anchor: .center) }
                }
            }
        }
    }

    private var line: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                if index > 0 {
                    Rectangle()
                        .fill(isDone(index - 1) ? Theme.accent.opacity(0.6) : Color.secondary.opacity(0.3))
                        .frame(width: 16, height: 2)
                }
                circle(index)
            }
        }
    }

    private func isDone(_ index: Int) -> Bool {
        completed.indices.contains(index) && completed[index]
    }

    private func circle(_ index: Int) -> some View {
        let isCurrent = index == current
        let done = isDone(index)
        return Button {
            onTap(index)
        } label: {
            Text("\(index + 1)")
                .font(.footnote.weight(.bold).monospacedDigit())
                .foregroundStyle(isCurrent ? Color.white : (done ? Theme.accent : Color.primary))
                .frame(width: 32, height: 32)
                .background(Circle().fill(isCurrent ? Theme.accent : (done ? Theme.accent.opacity(0.18) : Theme.card)))
                .overlay(Circle().strokeBorder(isCurrent ? Theme.accent : Color.secondary.opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .id(index)
    }
}

// MARK: - Set row

struct ActiveSetRow: View {
    let number: Int
    let set: SessionSet
    let mode: TrackingMode
    let isCurrent: Bool
    let weightStep: Double
    let onAdjust: (WorkoutManager.Field, Double) -> Void
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SET \(number)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(isCurrent ? Theme.accent : Color.secondary)
                Spacer()
                statusIcon
            }
            if isCurrent {
                steppers
            } else {
                Text(Fmt.setValue(set, mode: mode))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .strikethrough(set.status == .skipped)
                    .foregroundStyle(set.status == .skipped ? Color.secondary : Color.primary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isCurrent ? Theme.accent.opacity(0.14) : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isCurrent ? Theme.accent : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCurrent && set.status == .pending { onSelect() }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch set.status {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
        case .skipped:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        case .pending:
            if isCurrent {
                Text("NOW").font(.caption2.weight(.heavy)).foregroundStyle(Theme.accent)
            } else {
                Image(systemName: "circle").foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var steppers: some View {
        switch mode {
        case .weightReps:
            HStack(spacing: 10) {
                ValueStepper(value: "\(set.reps)", unit: "reps",
                             onMinus: { onAdjust(.reps, -1) },
                             onPlus: { onAdjust(.reps, 1) })
                ValueStepper(value: Fmt.num(set.weight), unit: "kg",
                             onMinus: { onAdjust(.weight, -weightStep) },
                             onPlus: { onAdjust(.weight, weightStep) })
            }
        case .timeDistance:
            HStack(spacing: 10) {
                ValueStepper(value: Fmt.num(set.minutes), unit: "min",
                             onMinus: { onAdjust(.minutes, -0.5) },
                             onPlus: { onAdjust(.minutes, 0.5) })
                ValueStepper(value: Fmt.num(set.meters), unit: "m",
                             onMinus: { onAdjust(.meters, -50) },
                             onPlus: { onAdjust(.meters, 50) })
            }
        }
    }
}

struct ValueStepper: View {
    let value: String
    let unit: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", action: onMinus)
            VStack(spacing: 0) {
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            stepButton("plus", action: onPlus)
        }
        .background(Capsule().fill(Theme.background))
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .frame(width: 42, height: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
    }
}

// MARK: - Rest timer

struct RestTimerControl: View {
    let session: WorkoutSession
    @Environment(WorkoutManager.self) private var workout

    var body: some View {
        Menu {
            if session.restEndDate != nil {
                Button { workout.adjustRest(by: 15) } label: { Label("+15 seconds", systemImage: "plus") }
                Button { workout.adjustRest(by: -15) } label: { Label("−15 seconds", systemImage: "minus") }
                Button(role: .destructive) { workout.skipRest() } label: { Label("Skip rest", systemImage: "forward.end") }
            } else {
                Button { workout.startRestNow() } label: { Label("Start rest timer", systemImage: "timer") }
            }
        } label: {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                label(now: context.date)
            }
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func label(now: Date) -> some View {
        if let end = session.restEndDate, end > now {
            let remaining = end.timeIntervalSince(now)
            let total = max(Double(session.restDuration), 1)
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Theme.accent.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: min(1, remaining / total))
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 26, height: 26)
                Text(Fmt.clock(remaining.rounded(.up)))
                    .font(.title2.weight(.bold).monospacedDigit())
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(Theme.accent.opacity(0.12)))
        } else {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text("Rest")
            }
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(Theme.card))
        }
    }
}
