import Foundation
import SwiftData

@Model
final class Trainer {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Trainee.trainer)
    var trainees: [Trainee]
    @Relationship(deleteRule: .cascade, inverse: \ExerciseDefinition.trainer)
    var exerciseDefinitions: [ExerciseDefinition]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.trainees = []
        self.exerciseDefinitions = []
    }

    /// Find or create an exercise definition by name (case-insensitive match).
    func findOrCreateExerciseDefinition(named name: String, in context: ModelContext) -> ExerciseDefinition {
        if let existing = exerciseDefinitions.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return existing
        }
        let definition = ExerciseDefinition(name: name, trainer: self)
        context.insert(definition)
        return definition
    }
}

@Model
final class ExerciseDefinition {
    var id: UUID
    var name: String
    var trainer: Trainer?
    @Relationship(deleteRule: .nullify, inverse: \Exercise.definition)
    var exercises: [Exercise]

    init(name: String, trainer: Trainer? = nil) {
        self.id = UUID()
        self.name = name
        self.trainer = trainer
        self.exercises = []
    }
}

@Model
final class Trainee {
    var id: UUID
    var name: String
    var trainer: Trainer?
    @Relationship(deleteRule: .cascade, inverse: \Workout.trainee)
    var workouts: [Workout]

    init(name: String, trainer: Trainer? = nil) {
        self.id = UUID()
        self.name = name
        self.trainer = trainer
        self.workouts = []
    }

    var activeWorkouts: [Workout] {
        workouts.filter { !$0.isComplete }
    }

    var completedWorkouts: [Workout] {
        workouts
            .filter { $0.isComplete }
            .sorted { $0.date > $1.date }
    }

    /// All unique exercise definitions this trainee has ever done, sorted alphabetically by name.
    var allExerciseDefinitions: [ExerciseDefinition] {
        let definitionsByID = Dictionary(
            workouts
                .flatMap { $0.exercises.compactMap { $0.definition } }
                .map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return definitionsByID.values.sorted { $0.name < $1.name }
    }

    /// Find the most recent completed exercise for a given exercise definition.
    func lastExercise(for definition: ExerciseDefinition) -> Exercise? {
        completedWorkouts
            .flatMap { $0.sortedExercises }
            .first { $0.definition?.id == definition.id }
    }

    /// All exercises for a given definition across all completed workouts, oldest first.
    func history(for definition: ExerciseDefinition) -> [(date: Date, exercise: Exercise)] {
        completedWorkouts
            .reversed() // oldest first
            .flatMap { workout in
                workout.exercises
                    .filter { $0.definition?.id == definition.id }
                    .map { (date: workout.date, exercise: $0) }
            }
    }
}

@Model
final class Workout {
    var id: UUID
    var trainee: Trainee?
    var date: Date
    var notes: String?
    var isComplete: Bool
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]

    init(trainee: Trainee? = nil, date: Date = .now) {
        self.id = UUID()
        self.trainee = trainee
        self.date = date
        self.notes = nil
        self.isComplete = false
        self.exercises = []
    }

    var sortedExercises: [Exercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var nextExerciseOrder: Int {
        (exercises.map(\.order).max() ?? -1) + 1
    }

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }

    var exerciseCount: Int {
        exercises.count
    }
}

@Model
final class Exercise {
    var id: UUID
    var workout: Workout?
    var definition: ExerciseDefinition?
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]

    init(definition: ExerciseDefinition, order: Int, workout: Workout? = nil) {
        self.id = UUID()
        self.definition = definition
        self.order = order
        self.workout = workout
        self.sets = []
    }

    var name: String {
        definition?.name ?? "Unknown"
    }

    var sortedSets: [WorkoutSet] {
        sets.sorted { $0.order < $1.order }
    }

    var nextSetOrder: Int {
        (sets.map(\.order).max() ?? -1) + 1
    }

    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }
}

@Model
final class WorkoutSet {
    var id: UUID
    var exercise: Exercise?
    var order: Int
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    var completedAt: Date?

    init(order: Int, weight: Double = 0, reps: Int = 0, exercise: Exercise? = nil) {
        self.id = UUID()
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isCompleted = false
        self.completedAt = nil
        self.exercise = exercise
    }

    var volume: Double {
        weight * Double(reps)
    }
}
