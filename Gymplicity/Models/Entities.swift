import Foundation
import SwiftData

// MARK: - Entities

@Model
final class IdentityEntity {
    var id: UUID
    var name: String
    var isTrainer: Bool

    init(name: String, isTrainer: Bool) {
        precondition(
            !name.trimmingCharacters(
                in: .whitespaces
            ).isEmpty,
            "IdentityEntity name must not be empty"
        )
        self.id = UUID()
        self.name = name
        self.isTrainer = isTrainer
    }
}

@Model
final class ExerciseEntity {
    var id: UUID
    var name: String

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

@Model
final class WorkoutEntity {
    var id: UUID
    var date: Date
    var isTemplate: Bool

    init(
        date: Date,
        isTemplate: Bool
    ) {
        self.id = UUID()
        self.date = date
        self.isTemplate = isTemplate
    }
}

@Model
final class WorkoutGroupEntity {
    var id: UUID
    var order: Int
    var isSuperset: Bool

    init(order: Int, isSuperset: Bool) {
        precondition(
            order >= 0,
            "WorkoutGroupEntity order must be non-negative"
        )
        self.id = UUID()
        self.order = order
        self.isSuperset = isSuperset
    }
}

@Model
final class SetEntity {
    var id: UUID
    var order: Int
    var weight: Double
    var reps: Int

    init(order: Int, weight: Double, reps: Int) {
        precondition(
            order >= 0,
            "SetEntity order must be non-negative"
        )
        precondition(
            weight >= 0,
            "SetEntity weight must be non-negative"
        )
        precondition(
            reps >= 0,
            "SetEntity reps must be non-negative"
        )
        self.id = UUID()
        self.order = order
        self.weight = weight
        self.reps = reps
    }

    var volume: Double {
        weight * Double(reps)
    }
}
