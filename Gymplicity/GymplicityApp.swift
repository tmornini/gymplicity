import SwiftUI
import SwiftData

@main
struct GymplicityApp: App {
    @StateObject private var syncManager =
        SyncSessionManager(
            name: "Gymplicity",
            role: "unknown"
        )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(syncManager)
                .environment(
                    \.exerciseSearchEngine,
                    ExerciseSearchEngine()
                )
        }
        .modelContainer(for: [
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
            TemplateInstances.self,
            WorkoutTemplate.self,
            WorkoutNotes.self,
            IdentityAliases.self,
            PairedDevices.self,
            SetCompletions.self,
            WorkoutCompletions.self,
            DeviceSyncEvents.self,
        ])
    }
}
