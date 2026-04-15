import SwiftUI
import SwiftData

struct ExerciseAttributePills: View {
    @Environment(\.exerciseSearchEngine) private var searchEngine
    @Environment(\.modelContext) private var modelContext
    let catalogExercise: CatalogExercise?
    let exerciseEntity: ExerciseEntity?

    init(exercise: CatalogExercise) {
        self.catalogExercise = exercise
        self.exerciseEntity = nil
    }

    init(exercise: ExerciseEntity?) {
        self.catalogExercise = nil
        self.exerciseEntity = exercise
    }

    private var resolvedExercise: CatalogExercise? {
        if let catalogExercise { return catalogExercise }
        guard let entity = exerciseEntity,
              let catalogId = entity.catalogId(in: modelContext)
        else { return nil }
        return searchEngine.catalogExercise(
            forCatalogId: catalogId
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
