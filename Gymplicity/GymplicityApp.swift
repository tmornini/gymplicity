import SwiftUI
import SwiftData

@main
struct GymplicityApp: App {
    var body: some Scene {
        WindowGroup {
            TrainerHomeView()
        }
        .modelContainer(for: [Trainer.self, ExerciseDefinition.self, Trainee.self, Workout.self, Exercise.self, WorkoutSet.self])
    }
}
