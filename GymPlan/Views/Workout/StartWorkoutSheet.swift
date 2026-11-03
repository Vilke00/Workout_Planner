import SwiftUI

/// Asks for the rest between exercises, then starts the workout.
struct StartWorkoutSheet: View {
    let plan: Plan
    let routine: Routine

    @Environment(WorkoutManager.self) private var workout
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Keys.restBetweenExercises) private var savedRest = 120

    @State private var minutes = 2
    @State private var seconds = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text(routine.name)
                        .font(.title3.bold())
                    Text("\(routine.exercises.count) exercises · \(totalSets) sets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                Text("Rest between exercises")
                    .font(.headline)
                    .padding(.top, 12)

                RestWheels(minutes: $minutes, seconds: $seconds)
                    .frame(height: 180)
                    .padding(.horizontal)

                Spacer(minLength: 0)
            }
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { start() }
                        .bold()
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            minutes = min(savedRest / 60, 30)
            seconds = (savedRest % 60) / 5 * 5
        }
    }

    private var totalSets: Int {
        routine.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func start() {
        let rest = minutes * 60 + seconds
        savedRest = rest
        let manager = workout
        let plan = plan
        let routine = routine
        dismiss()
        // Let the sheet close before the full-screen workout appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            manager.start(plan: plan, routine: routine, restBetweenExercises: rest)
        }
    }
}
