import Foundation
import SwiftData

@Model
final class Trainer {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Trainee.trainer)
    var trainees: [Trainee]
    @Relationship(deleteRule: .cascade, inverse: \Exercise.trainer)
    var exercises: [Exercise]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.trainees = []
        self.exercises = []
    }

    /// Find or create an exercise by name (case-insensitive match).
    func findOrCreateExercise(named name: String, in context: ModelContext) -> Exercise {
        if let existing = exercises.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return existing
        }
        let exercise = Exercise(name: name, trainer: self)
        context.insert(exercise)
        return exercise
    }
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var trainer: Trainer?
    @Relationship(deleteRule: .nullify, inverse: \SessionEntry.exercise)
    var entries: [SessionEntry]

    init(name: String, trainer: Trainer? = nil) {
        self.id = UUID()
        self.name = name
        self.trainer = trainer
        self.entries = []
    }
}

@Model
final class Trainee {
    var id: UUID
    var name: String
    var trainer: Trainer?
    @Relationship(deleteRule: .cascade, inverse: \Session.trainee)
    var sessions: [Session]

    init(name: String, trainer: Trainer? = nil) {
        self.id = UUID()
        self.name = name
        self.trainer = trainer
        self.sessions = []
    }

    var activeSessions: [Session] {
        sessions.filter { !$0.isComplete }
    }

    var completedSessions: [Session] {
        sessions
            .filter { $0.isComplete }
            .sorted { $0.date > $1.date }
    }

    /// All unique exercises this trainee has ever done, sorted alphabetically by name.
    var allExercises: [Exercise] {
        let exercisesByID = Dictionary(
            sessions
                .flatMap { $0.entries.compactMap { $0.exercise } }
                .map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return exercisesByID.values.sorted { $0.name < $1.name }
    }

    /// Find the most recent completed session entry for a given exercise.
    func lastEntry(for exercise: Exercise) -> SessionEntry? {
        completedSessions
            .flatMap { $0.sortedEntries }
            .first { $0.exercise?.id == exercise.id }
    }

    /// All session entries for a given exercise across all completed sessions, oldest first.
    func history(for exercise: Exercise) -> [(date: Date, entry: SessionEntry)] {
        completedSessions
            .reversed() // oldest first
            .flatMap { session in
                session.entries
                    .filter { $0.exercise?.id == exercise.id }
                    .map { (date: session.date, entry: $0) }
            }
    }
}

@Model
final class Session {
    var id: UUID
    var trainee: Trainee?
    var date: Date
    var notes: String?
    var isComplete: Bool
    @Relationship(deleteRule: .cascade, inverse: \SessionEntry.session)
    var entries: [SessionEntry]

    init(trainee: Trainee? = nil, date: Date = .now) {
        self.id = UUID()
        self.trainee = trainee
        self.date = date
        self.notes = nil
        self.isComplete = false
        self.entries = []
    }

    var sortedEntries: [SessionEntry] {
        entries.sorted { $0.order < $1.order }
    }

    var nextEntryOrder: Int {
        (entries.map(\.order).max() ?? -1) + 1
    }

    var totalVolume: Double {
        entries.reduce(0) { $0 + $1.totalVolume }
    }

    var exerciseCount: Int {
        entries.count
    }
}

@Model
final class SessionEntry {
    var id: UUID
    var session: Session?
    var exercise: Exercise?
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.entry)
    var sets: [ExerciseSet]

    init(exercise: Exercise, order: Int, session: Session? = nil) {
        self.id = UUID()
        self.exercise = exercise
        self.order = order
        self.session = session
        self.sets = []
    }

    var exerciseName: String {
        exercise?.name ?? "Unknown"
    }

    var sortedSets: [ExerciseSet] {
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
final class ExerciseSet {
    var id: UUID
    var entry: SessionEntry?
    var order: Int
    var weight: Double
    var reps: Int
    var isCompleted: Bool
    var completedAt: Date?

    init(order: Int, weight: Double = 0, reps: Int = 0, entry: SessionEntry? = nil) {
        self.id = UUID()
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isCompleted = false
        self.completedAt = nil
        self.entry = entry
    }

    var volume: Double {
        weight * Double(reps)
    }
}
