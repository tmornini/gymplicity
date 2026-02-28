import Foundation
import SwiftData

@Model
final class Trainer {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Trainee.trainer)
    var trainees: [Trainee]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.trainees = []
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

    /// All unique exercise names this trainee has ever done, sorted alphabetically.
    var allExerciseNames: [String] {
        let names = sessions.flatMap { $0.entries.map { $0.exerciseName } }
        return Array(Set(names)).sorted()
    }

    /// Find the most recent completed session entry for a given exercise name.
    func lastEntry(for exerciseName: String) -> SessionEntry? {
        completedSessions
            .flatMap { $0.sortedEntries }
            .first { $0.exerciseName.lowercased() == exerciseName.lowercased() }
    }

    /// All session entries for a given exercise name across all completed sessions, oldest first.
    func history(for exerciseName: String) -> [(date: Date, entry: SessionEntry)] {
        completedSessions
            .reversed() // oldest first
            .flatMap { session in
                session.entries
                    .filter { $0.exerciseName.lowercased() == exerciseName.lowercased() }
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
    var exerciseName: String
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.entry)
    var sets: [ExerciseSet]

    init(exerciseName: String, order: Int, session: Session? = nil) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.order = order
        self.session = session
        self.sets = []
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

    init(order: Int, weight: Double = 0, reps: Int = 0, entry: SessionEntry? = nil) {
        self.id = UUID()
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isCompleted = false
        self.entry = entry
    }

    var volume: Double {
        weight * Double(reps)
    }
}
