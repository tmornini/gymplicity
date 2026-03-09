import Foundation
import SwiftData

// MARK: - WorkoutSnapshot

/// View-friendly value type wrapping a workout and its pre-fetched subgraph.
/// All computed properties (exerciseCount, volume, names) are derived from
/// the snapshot without additional SwiftData queries.
struct WorkoutSnapshot {
    let workout: WorkoutEntity
    let groups: [GroupSnapshot]
    let subgraph: WorkoutSubgraph

    var exerciseCount: Int { subgraph.exerciseCount(for: workout.id) }
    var totalVolume: Double { subgraph.totalVolume(for: workout.id) }
    var exerciseNames: String { subgraph.exerciseNames(for: workout.id) }
    var completionProgress: Double { subgraph.completionProgress(for: workout.id) }

    var allSetsFlattened: [(group: WorkoutGroupEntity, set: SetEntity)] {
        subgraph.allSetsFlattened(for: workout.id)
    }

    struct GroupSnapshot: Identifiable {
        let group: WorkoutGroupEntity
        let sets: [SetSnapshot]
        let exerciseName: String
        var id: UUID { group.id }
    }

    struct SetSnapshot: Identifiable {
        let set: SetEntity
        let exercise: ExerciseEntity?
        var id: UUID { self.set.id }
    }

    /// Load a single workout snapshot.
    @MainActor static func load(_ workout: WorkoutEntity, in context: ModelContext) -> WorkoutSnapshot {
        let subgraph = BatchTraversal.workoutSubgraph(workoutIds: [workout.id], in: context)
        return build(workout: workout, subgraph: subgraph)
    }

    /// Load snapshots for multiple workouts in a single batch.
    @MainActor static func loadAll(_ workouts: [WorkoutEntity], in context: ModelContext) -> [WorkoutSnapshot] {
        guard !workouts.isEmpty else { return [] }
        let subgraph = BatchTraversal.workoutSubgraph(workoutIds: workouts.map(\.id), in: context)
        return workouts.map { build(workout: $0, subgraph: subgraph) }
    }

    private static func build(workout: WorkoutEntity, subgraph: WorkoutSubgraph) -> WorkoutSnapshot {
        let groupSnapshots = subgraph.sortedGroups(for: workout.id).map { group in
            let setSnapshots = subgraph.sortedSets(for: group.id).map { set in
                SetSnapshot(set: set, exercise: subgraph.exerciseBySet[set.id])
            }
            return GroupSnapshot(
                group: group,
                sets: setSnapshots,
                exerciseName: subgraph.exerciseName(for: group.id)
            )
        }
        return WorkoutSnapshot(workout: workout, groups: groupSnapshots, subgraph: subgraph)
    }
}
