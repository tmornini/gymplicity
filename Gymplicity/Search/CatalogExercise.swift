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
    let nameTokens: [String]
    let aliasTokens: [String]
    let muscleTokens: [String]
    let jointTokens: [String]
    let regionTokens: [String]
    let searchBlob: String

    init(_ exercise: CatalogExercise) {
        self.exercise = exercise
        self.nameTokens = exercise.name.lowercased().split(separator: " ").map(String.init)
        self.aliasTokens = exercise.aliases.flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        self.muscleTokens = exercise.primaryMuscles + exercise.secondaryMuscles
        self.jointTokens = exercise.joints
        self.regionTokens = exercise.bodyRegions
        self.searchBlob = (
            [exercise.name.lowercased()] +
            exercise.aliases.map { $0.lowercased() } +
            exercise.primaryMuscles +
            exercise.secondaryMuscles +
            exercise.joints +
            exercise.bodyRegions
        ).joined(separator: " ")
    }
}
