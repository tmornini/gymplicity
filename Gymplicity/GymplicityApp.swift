import SwiftUI
import SwiftData

@main
struct GymplicityApp: App {
    var body: some Scene {
        WindowGroup {
            TrainerHomeView()
        }
        .modelContainer(for: [Trainer.self, Trainee.self, Session.self, SessionEntry.self, ExerciseSet.self])
    }
}
