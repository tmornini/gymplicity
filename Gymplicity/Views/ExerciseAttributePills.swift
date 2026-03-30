import SwiftUI

struct ExerciseAttributePills: View {
    @Environment(\.exerciseSearchEngine) private var searchEngine
    let catalogExercise: CatalogExercise?
    let entityCatalogId: String?

    init(exercise: CatalogExercise) {
        self.catalogExercise = exercise
        self.entityCatalogId = nil
    }

    init(exercise: ExerciseEntity?) {
        self.catalogExercise = nil
        self.entityCatalogId = exercise?.catalogId
    }

    private var resolvedExercise: CatalogExercise? {
        if let catalogExercise { return catalogExercise }
        guard let entityCatalogId else { return nil }
        return searchEngine.catalogExercise(
            forCatalogId: entityCatalogId
        )
    }

    var body: some View {
        if let exercise = resolvedExercise {
            HStack(alignment: .top, spacing: GymMetrics.space8) {
                pillColumn(
                    exercise.bodyRegions,
                    color: GymColors.secondaryText
                )
                pillColumn(exercise.primaryMuscles, color: GymColors.power)
                pillColumn(exercise.joints, color: GymColors.warning)
            }
        }
    }

    @ViewBuilder
    private func pillColumn(_ values: [String], color: Color) -> some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: GymMetrics.space4) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .gymPill(color)
                }
            }
        }
    }
}
