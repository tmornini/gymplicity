import SwiftUI

struct ExerciseAttributePills: View {
    let catalogExercise: CatalogExercise?

    init(exercise: CatalogExercise) {
        self.catalogExercise = exercise
    }

    init(exercise: ExerciseEntity?) {
        if let catalogId = exercise?.catalogId {
            self.catalogExercise = ExerciseSearchEngine.shared.catalogExercise(forCatalogId: catalogId)
        } else {
            self.catalogExercise = nil
        }
    }

    var body: some View {
        if let exercise = catalogExercise {
            HStack(alignment: .top, spacing: GymMetrics.space8) {
                pillColumn(exercise.bodyRegions, color: GymColors.secondaryText)
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
