import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct GymPlanWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}

private enum LAStyle {
    static let accent = Color(red: 0.38, green: 0.40, blue: 1.0)
    static let field = Color.white.opacity(0.12)
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenWorkoutView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TotalTimerText(startDate: context.attributes.startDate)
                        .font(.headline)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WorkoutControlsView(state: context.state, compact: true)
                }
            } compactLeading: {
                Text(context.state.finished ? "✓" : "\(context.state.setNumber)/\(context.state.setCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LAStyle.accent)
            } compactTrailing: {
                CompactTimerText(attributes: context.attributes, state: context.state)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(LAStyle.accent)
            }
            .keylineTint(LAStyle.accent)
        }
    }
}

/// Lock screen card:
/// [Exercise name ................. total timer]
/// [Set 2/4   (−) 10 reps (+)   (−) 60 kg (+)]
/// [ (X)        rest timer          (Done)    ]
struct LockScreenWorkoutView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                TotalTimerText(startDate: attributes.startDate)
                    .font(.headline)
            }
            WorkoutControlsView(state: state, compact: false)
        }
        .foregroundStyle(Color.white)
        .padding(14)
    }
}

struct WorkoutControlsView: View {
    let state: WorkoutActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        if state.finished {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(LAStyle.accent)
                Text("All sets done – open the app and tap Finish")
                    .font(.subheadline)
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: compact ? 6 : 10) {
                HStack(spacing: 6) {
                    Text("Set \(state.setNumber)/\(state.setCount)")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                    Spacer(minLength: 4)
                    ActivityStepper(value: state.firstValue, unit: state.firstUnit, index: 0)
                    ActivityStepper(value: state.secondValue, unit: state.secondUnit, index: 1)
                }
                HStack(spacing: 10) {
                    Button(intent: SkipSetIntent()) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(LAStyle.field))
                    }
                    .buttonStyle(.plain)

                    RestTimerView(state: state)
                        .frame(maxWidth: .infinity)

                    Button(intent: CompleteSetIntent()) {
                        Text("Done")
                            .font(.headline)
                            .frame(width: 76, height: 40)
                            .background(Capsule().fill(LAStyle.accent))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ActivityStepper: View {
    let value: String
    let unit: String
    let index: Int

    var body: some View {
        HStack(spacing: 0) {
            Button(intent: AdjustSetIntent(value: index, direction: -1)) {
                Image(systemName: "minus")
                    .font(.caption.weight(.bold))
                    .frame(width: 26, height: 32)
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 9))
                    .opacity(0.7)
            }
            .frame(minWidth: 34)

            Button(intent: AdjustSetIntent(value: index, direction: 1)) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 26, height: 32)
            }
            .buttonStyle(.plain)
        }
        .background(Capsule().fill(LAStyle.field))
    }
}

struct RestTimerView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if let start = state.restStart, let end = state.restEnd, end > Date(), start <= end {
            Button(intent: SkipRestIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text(timerInterval: start...end, countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 60)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(LAStyle.accent.opacity(0.35)))
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text("Rest")
            }
            .font(.subheadline.weight(.semibold))
            .opacity(0.7)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Capsule().fill(LAStyle.field))
        }
    }
}

struct TotalTimerText: View {
    let startDate: Date

    var body: some View {
        Text(startDate, style: .timer)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(width: 72, alignment: .trailing)
    }
}

struct CompactTimerText: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if let start = state.restStart, let end = state.restEnd, end > Date(), start <= end {
            Text(timerInterval: start...end, countsDown: true)
                .monospacedDigit()
                .font(.caption.weight(.bold))
                .foregroundStyle(LAStyle.accent)
                .frame(width: 44)
        } else {
            Text(attributes.startDate, style: .timer)
                .monospacedDigit()
                .font(.caption.weight(.bold))
                .frame(width: 44)
        }
    }
}
