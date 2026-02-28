import SwiftUI
import SwiftData

@main
struct GymplicityApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [
            IdentityEntity.self,
            ExerciseEntity.self,
            WorkoutEntity.self,
            SupersetEntity.self,
            SetEntity.self,
            TrainerTrainees.self,
            TrainerExercises.self,
            IdentityWorkouts.self,
            WorkoutSupersets.self,
            SupersetSets.self,
            ExerciseSets.self,
        ])
    }
}
