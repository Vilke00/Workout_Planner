import SwiftUI
import UIKit

/// A set in the workout: exercise index + set index.
struct SetRef: Hashable {
    let exercise: Int
    let set: Int
}

/// Full-screen workout: total timer, exercise line, swipeable exercise pages, and X / rest timer / Done bar.
struct ActiveWorkoutView: View {
    @Environment(WorkoutManager.self) private var workout
    @Environment(AppStore.self) private var store
    @AppStorage(AppSettings.Keys.weightStep) private var weightStep = 2.5

    /// Exercise shown on screen. Swiping only changes what you look at, not the current set.
    @State private var page = 0
    @State private var editing: SetRef?
    @State private var historyTarget: SessionExercise?
    @State private var showEndOptions = false
    @State private var doneCount = 0

    var body: some View {
        NavigationStack {
            Group {
                if let session = workout.session, !session.exercises.isEmpty {
                    content(session)
                } else {
                    Color(uiColor: .systemBackground)
                        .onAppear { workout.isPresented = false }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { hideKeyboard() }
                        .bold()
                }
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
        .onAppear {
            if let s = workout.session { page = currentExercise(s) }
        }
        .onChange(of: workout.session?.stepIndex) { _, _ in
            editing = nil
            guard let s = workout.session, !s.isFinished else { return }
            withAnimation(.easeInOut(duration: 0.3)) { page = currentExercise(s) }
        }
    }

    private func currentExercise(_ s: WorkoutSession) -> Int {
        s.currentStep?.exerciseIndex ?? max(0, s.exercises.count - 1)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: Layout

    @ViewBuilder
    private func content(_ s: WorkoutSession) -> some View {
        let shown = min(max(page, 0), s.exercises.count - 1)

        VStack(spacing: 0) {
            topBar(s)

            ExerciseProgressLine(count: s.exercises.count,
                                 current: shown,
                                 completed: s.exercises.indices.map { s.isExerciseComplete($0) }) { index in
                _ = workout.jump(toExercise: index)
                withAnimation(.easeInOut(duration: 0.3)) { page = index }
            }
            .padding(.vertical, 10)

            TabView(selection: $page) {
                ForEach(s.exercises.indices, id: \.self) { index in
                    exercisePage(s, exerciseIndex: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomBar(s)
        }
        .background(Theme.background)
    }

    private func exercisePage(_ s: WorkoutSession, exerciseIndex: Int) -> some View {
        let exercise = s.exercises[exerciseIndex]
        let isCurrentExercise = s.currentStep?.exerciseIndex == exerciseIndex
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ExerciseImageView(exercise: store.exercise(exercise.exerciseID), animated: true, fill: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: 230)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                titleRow(exercise, inSuperset: s.isInSuperset(exerciseIndex))

                if !isCurrentExercise && !s.isFinished {
                    backToCurrent(s)
                }

                setsList(s, exerciseIndex: exerciseIndex)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Shown when you swiped away from the exercise you're doing.
    private func backToCurrent(_ s: WorkoutSession) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) { page = currentExercise(s) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                Text("Back to current: \(s.exercises[currentExercise(s)].name)")
                    .lineLimit(1)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.accent.opacity(0.14)))
        }
        .foregroundStyle(Theme.accent)
    }

    private func topBar(_ s: WorkoutSession) -> some View {
        HStack {
            Button {
                hideKeyboard()
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
                hideKeyboard()
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
                if exercise.mode == .weightReps, let target = exercise.target?.text {
                    Label("Target \(target)", systemImage: "scope")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
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
                let ref = SetRef(exercise: exerciseIndex, set: index)
                ActiveSetRow(number: index + 1,
                             set: set,
                             mode: exercise.mode,
                             isCurrent: s.currentStep?.exerciseIndex == exerciseIndex && s.currentStep?.setIndex == index,
                             isEditing: editing == ref,
                             target: exercise.mode == .weightReps ? exercise.target?.text : nil,
                             weightStep: weightStep,
                             onAdjust: { field, delta in
                                 workout.adjust(field, by: delta, exerciseIndex: exerciseIndex, setIndex: index)
                             },
                             onSetValue: { field, value in
                                 workout.setValue(field, to: value, exerciseIndex: exerciseIndex, setIndex: index)
                             },
                             onTap: {
                                 if set.status == .pending {
                                     _ = workout.jump(toExercise: exerciseIndex, set: index)
                                 } else {
                                     withAnimation(.snappy) { editing = ref }
                                 }
                             },
                             onCloseEdit: {
                                 hideKeyboard()
                                 withAnimation(.snappy) { editing = nil }
                             },
                             onStatus: { status in
                                 hideKeyboard()
                                 editing = nil
                                 workout.setStatus(status, exerciseIndex: exerciseIndex, setIndex: index)
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
                    hideKeyboard()
                    workout.finish()
                } label: {
                    Text("Finish")
                        .font(.headline)
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Theme.accent))
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 14) {
                    Button {
                        hideKeyboard()
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
                        hideKeyboard()
                        workout.completeCurrentSet()
                        doneCount += 1
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 100, height: 56)
                            .background(Capsule().fill(Theme.accent))
                            .shadow(color: Theme.accent.opacity(0.55), radius: 11)
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
                .foregroundStyle(isCurrent ? Theme.onAccent : (done ? Theme.accent : Color.primary))
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
    let isEditing: Bool
    /// Rep target shown on the current set, e.g. "8–12 reps" (display only).
    let target: String?
    let weightStep: Double
    let onAdjust: (WorkoutManager.Field, Double) -> Void
    let onSetValue: (WorkoutManager.Field, Double) -> Void
    /// Tap on a row that isn't current: pending → make it current, done/skipped → edit it.
    let onTap: () -> Void
    let onCloseEdit: () -> Void
    let onStatus: (SetStatus) -> Void

    private var showsEditors: Bool { isCurrent || isEditing }
    private var highlight: Color { isEditing ? Theme.edit : Theme.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if showsEditors {
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
            .fill(showsEditors ? highlight.opacity(0.14) : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(showsEditors ? highlight : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        // The row tap is off while editors are shown so it never steals taps from the text fields.
        .gesture(TapGesture().onEnded { onTap() }, including: showsEditors ? .subviews : .all)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Text(isEditing ? "SET \(number) · EDITING" : "SET \(number)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(showsEditors ? highlight : Color.secondary)
            if isCurrent, let target {
                Text("Target \(target)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent.opacity(0.18)))
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            if isEditing {
                Menu {
                    if set.status == .done {
                        Button { onStatus(.pending) } label: {
                            Label("Mark as not done", systemImage: "arrow.uturn.backward")
                        }
                        Button { onStatus(.skipped) } label: {
                            Label("Mark as skipped", systemImage: "xmark")
                        }
                    } else {
                        Button { onStatus(.done) } label: {
                            Label("Mark as done", systemImage: "checkmark")
                        }
                        Button { onStatus(.pending) } label: {
                            Label("Mark as not done", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(highlight)
                }
                Button(action: onCloseEdit) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(highlight)
                }
                .buttonStyle(.plain)
            } else {
                statusIcon
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch set.status {
        case .done:
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            }
        case .skipped:
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
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
                ValueStepper(value: Double(set.reps), unit: "reps", isInteger: true, tint: highlight,
                             onMinus: { onAdjust(.reps, -1) },
                             onPlus: { onAdjust(.reps, 1) },
                             onSet: { onSetValue(.reps, $0) })
                ValueStepper(value: set.weight, unit: "kg", isInteger: false, tint: highlight,
                             onMinus: { onAdjust(.weight, -weightStep) },
                             onPlus: { onAdjust(.weight, weightStep) },
                             onSet: { onSetValue(.weight, $0) })
            }
        case .timeDistance:
            HStack(spacing: 10) {
                ValueStepper(value: set.minutes, unit: "min", isInteger: false, tint: highlight,
                             onMinus: { onAdjust(.minutes, -0.5) },
                             onPlus: { onAdjust(.minutes, 0.5) },
                             onSet: { onSetValue(.minutes, $0) })
                ValueStepper(value: set.meters, unit: "m", isInteger: false, tint: highlight,
                             onMinus: { onAdjust(.meters, -50) },
                             onPlus: { onAdjust(.meters, 50) },
                             onSet: { onSetValue(.meters, $0) })
            }
        }
    }
}

/// − value + where the value can also be typed. Tapping the number clears it (the old value
/// stays as a grey hint), so typing 200 replaces 60 right away.
struct ValueStepper: View {
    let value: Double
    let unit: String
    let isInteger: Bool
    var tint: Color = Theme.accent
    let onMinus: () -> Void
    let onPlus: () -> Void
    let onSet: (Double) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var formatted: String {
        isInteger ? String(Int(value.rounded())) : Fmt.num(value)
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", action: onMinus)
            VStack(spacing: 0) {
                TextField(formatted, text: $text)
                    .keyboardType(isInteger ? .numberPad : .decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .focused($focused)
                    .lineLimit(1)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            stepButton("plus", action: onPlus)
        }
        .background(Capsule().fill(Theme.background))
        .overlay(Capsule().strokeBorder(focused ? tint : Color.clear, lineWidth: 1.5))
        .onAppear { text = formatted }
        .onChange(of: value) { _, _ in
            if !focused { text = formatted }
        }
        .onChange(of: focused) { _, isFocused in
            text = isFocused ? "" : formatted
        }
        .onChange(of: text) { _, newText in
            guard focused else { return }
            let cleaned = newText.trimmed.replacingOccurrences(of: ",", with: ".")
            guard !cleaned.isEmpty, let typed = Double(cleaned), typed.isFinite, typed >= 0 else { return }
            let newValue = isInteger ? typed.rounded() : typed
            if abs(newValue - value) > 0.0001 { onSet(newValue) }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            focused = false
            action()
        } label: {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .frame(width: 42, height: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
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
