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
    var catalogId: String?

    init(
        name: String,
        catalogId: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.catalogId = catalogId
    }
}

@Model
final class WorkoutEntity {
    var id: UUID
    var date: Date
    var notes: String?
    var isTemplate: Bool
    var templateName: String?

    init(
        date: Date = .now,
        isTemplate: Bool,
        templateName: String? = nil
    ) {
        precondition(
            !isTemplate || templateName != nil,
            "Templates must have a templateName"
        )
        self.id = UUID()
        self.date = date
        self.notes = nil
        self.isTemplate = isTemplate
        self.templateName = templateName
    }
}

@Model
final class WorkoutGroupEntity {
    var id: UUID
    var order: Int
    var isSuperset: Bool

    init(order: Int, isSuperset: Bool = false) {
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
        self.id = UUID()
        self.order = order
        self.weight = weight
        self.reps = reps
    }

    var volume: Double {
        weight * Double(reps)
    }
}
