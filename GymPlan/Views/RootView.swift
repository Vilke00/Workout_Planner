import SwiftUI

struct RootView: View {
    @Environment(WorkoutManager.self) private var workout

    var body: some View {
        @Bindable var workout = workout
        TabView {
            PlansHomeView()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }
            StatsView()
                .tabItem { Label("Statistics", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .fullScreenCover(isPresented: $workout.isPresented) {
            ActiveWorkoutView()
        }
        .alert("Next workout", isPresented: Binding(get: { workout.progressionSummary != nil },
                                                    set: { if !$0 { workout.progressionSummary = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workout.progressionSummary ?? "")
        }
    }
}
