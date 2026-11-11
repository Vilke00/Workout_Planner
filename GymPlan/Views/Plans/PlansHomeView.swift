import SwiftUI

/// Main "Workouts" screen: plan dropdown, routine tabs, routine pages and the floating action bar.
struct PlansHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(WorkoutManager.self) private var workout

    @State private var selectedRoutineID: UUID?
    @State private var showPlanMenu = false
    @State private var showNewPlan = false
    @State private var newPlanName = ""
    @State private var showAddRoutine = false
    @State private var newRoutineName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Theme.background)
        .onAppear(perform: syncSelection)
        .onChange(of: store.selectedPlanID) { _, _ in
            selectedRoutineID = store.selectedPlan?.routines.first?.id
        }
        .onChange(of: store.selectedPlan?.routines.map(\.id)) { _, _ in
            syncSelection()
        }
        .sheet(isPresented: $showPlanMenu) {
            if let plan = store.selectedPlan {
                PlanMenuSheet(planID: plan.id)
            }
        }
        .alert("New Plan", isPresented: $showNewPlan) {
            TextField("Plan name", text: $newPlanName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let name = newPlanName.trimmed
                if !name.isEmpty { store.addPlan(name: name) }
            }
        }
        .alert("New Routine", isPresented: $showAddRoutine) {
            TextField("Routine name", text: $newRoutineName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let name = newRoutineName.trimmed
                if !name.isEmpty, let plan = store.selectedPlan {
                    selectedRoutineID = store.addRoutine(planID: plan.id, name: name)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Plan", selection: Binding(get: { store.selectedPlanID },
                                                  set: { store.selectPlan($0) })) {
                    ForEach(store.plans) { plan in
                        Text(plan.name).tag(Optional(plan.id))
                    }
                }
                Divider()
                Button {
                    newPlanName = ""
                    showNewPlan = true
                } label: {
                    Label("New Plan", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(store.selectedPlan?.name ?? "No plan")
                        .font(.title2.bold())
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                showPlanMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
            }
            .disabled(store.selectedPlan == nil)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let plan = store.selectedPlan {
            if plan.routines.isEmpty {
                emptyRoutines
            } else {
                RoutineTabBar(routines: plan.routines, selection: $selectedRoutineID)
                if workout.isActive {
                    ResumeWorkoutBanner()
                }
                TabView(selection: $selectedRoutineID) {
                    ForEach(plan.routines) { routine in
                        RoutinePageView(planID: plan.id, routine: routine)
                            .tag(Optional(routine.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .overlay(alignment: .bottom) {
                    if let routine = currentRoutine(in: plan) {
                        RoutineActionBar(plan: plan, routine: routine)
                    }
                }
            }
        } else {
            ContentUnavailableView {
                Label("No plans yet", systemImage: "list.bullet.rectangle")
            } description: {
                Text("Create a plan, then add routines like Upper, Lower or Full Body.")
            } actions: {
                Button("Create Plan") {
                    newPlanName = ""
                    showNewPlan = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyRoutines: some View {
        ContentUnavailableView {
            Label("No routines", systemImage: "calendar.badge.plus")
        } description: {
            Text("Routines are the workouts in this plan, for example Daily, Full Body, Upper and Lower.")
        } actions: {
            Button("Add Routine") {
                newRoutineName = ""
                showAddRoutine = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func currentRoutine(in plan: Plan) -> Routine? {
        plan.routines.first { $0.id == selectedRoutineID } ?? plan.routines.first
    }

    private func syncSelection() {
        guard let plan = store.selectedPlan else { return }
        if !plan.routines.contains(where: { $0.id == selectedRoutineID }) {
            selectedRoutineID = plan.routines.first?.id
        }
    }
}

// MARK: - Routine tabs

struct RoutineTabBar: View {
    let routines: [Routine]
    @Binding var selection: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(routines) { routine in
                        tab(routine)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: selection) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func tab(_ routine: Routine) -> some View {
        let isSelected = routine.id == selection
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { selection = routine.id }
        } label: {
            VStack(spacing: 6) {
                Text(routine.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                Capsule()
                    .fill(isSelected ? Theme.accent : Color.clear)
                    .frame(height: 3)
                    .shadow(color: isSelected ? Theme.accent.opacity(0.9) : Color.clear, radius: 4)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .id(routine.id)
    }
}

// MARK: - Resume banner

struct ResumeWorkoutBanner: View {
    @Environment(WorkoutManager.self) private var workout

    var body: some View {
        if let session = workout.session {
            Button {
                workout.isPresented = true
            } label: {
                HStack(spacing: 10) {
                    Circle().fill(Theme.danger).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Workout in progress")
                            .font(.subheadline.weight(.semibold))
                        Text(session.routineName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Fmt.clock(context.date.timeIntervalSince(session.startDate)))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 4)
        }
    }
}
