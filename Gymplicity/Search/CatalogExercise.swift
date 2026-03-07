import Foundation

struct CatalogExercise: Codable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let joints: [String]
    let bodyRegions: [String]
    let equipment: [String]
}

struct IndexedCatalogExercise {
    let exercise: CatalogExercise
    let nameWords: [String]
    let aliasWords: [String]
    let primaryMuscleWords: [String]
    let secondaryMuscleWords: [String]
    let jointWords: [String]
    let regionWords: [String]
    let searchBlob: String

    init(_ exercise: CatalogExercise) {
        self.exercise = exercise
        self.nameWords = exercise.name.lowercased().split(separator: " ").map(String.init)
        self.aliasWords = exercise.aliases.flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        self.primaryMuscleWords = exercise.primaryMuscles.flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        self.secondaryMuscleWords = exercise.secondaryMuscles.flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        self.jointWords = exercise.joints.flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        self.regionWords = exercise.bodyRegions.flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        self.searchBlob = (
            [exercise.name.lowercased()] +
            exercise.aliases.map { $0.lowercased() } +
            exercise.primaryMuscles.map { $0.lowercased() } +
            exercise.secondaryMuscles.map { $0.lowercased() } +
            exercise.joints.map { $0.lowercased() } +
            exercise.bodyRegions.map { $0.lowercased() }
        ).joined(separator: " ")
    }
}
