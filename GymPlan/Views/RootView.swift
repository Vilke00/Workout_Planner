import SwiftUI

struct RootView: View {
    @Environment(WorkoutManager.self) private var workout
    @State private var importer = ImportCoordinator.shared

    var body: some View {
        @Bindable var workout = workout
        @Bindable var importer = importer
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
        .sheet(item: $importer.preview) { item in
            ImportPreviewView(preview: item)
        }
        .alert("Import failed", isPresented: $importer.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importer.errorMessage ?? "Unknown error")
        }
        .onOpenURL { url in
            // "Open in Gym Plan" / Share from Files, Mail, etc.
            if url.isFileURL { importer.load(url) }
        }
    }
}
