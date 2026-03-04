import Foundation
import SwiftData

// MARK: - Entities

@Model
final class IdentityEntity {
    var id: UUID
    var name: String
    var isTrainer: Bool

    init(name: String, isTrainer: Bool = false) {
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
    var notes: String?
    var isCompleted: Bool
    var isTemplate: Bool
    var templateName: String?
    init(date: Date = .now, isTemplate: Bool = false, templateName: String? = nil) {
        self.id = UUID()
        self.date = date
        self.notes = nil
        self.isCompleted = false
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
    var isCompleted: Bool
    var completedAt: Date?

    init(order: Int, weight: Double = 0, reps: Int = 0) {
        self.id = UUID()
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isCompleted = false
        self.completedAt = nil
    }

    var volume: Double {
        weight * Double(reps)
    }
}
