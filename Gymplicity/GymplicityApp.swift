import SwiftUI
import SwiftData

@main
struct GymplicityApp: App {
    @StateObject private var syncManager = SyncSessionManager(name: "Gymplicity", role: "unknown")
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            IdentityEntity.self,
            ExerciseEntity.self,
            WorkoutEntity.self,
            WorkoutGroupEntity.self,
            SetEntity.self,
            TrainerTrainees.self,
            TrainerExercises.self,
            IdentityWorkouts.self,
            WorkoutGroups.self,
            GroupSets.self,
            ExerciseSets.self,
            PairedDevices.self,
        ])
        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(syncManager)
                .onAppear {
                    syncManager.startAutoSync(container: modelContainer)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        syncManager.startAutoSync(container: modelContainer)
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
