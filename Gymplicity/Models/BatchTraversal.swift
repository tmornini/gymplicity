import Foundation
import SwiftData

// MARK: - WorkoutSubgraph

/// Pre-fetched workout data tree. All relationships
/// resolved via in-memory lookups instead of per-entity
/// SwiftData queries. ~6 queries total regardless of
/// data size.
struct WorkoutSubgraph {
    let groupsByWorkout: [UUID: [WorkoutGroupEntity]]
    let setsByGroup: [UUID: [SetEntity]]
    let exerciseBySet: [UUID: ExerciseEntity]
    let completedSetIds: Set<UUID>
    let completedWorkoutIds: Set<UUID>

    func sortedGroups(
        for workoutId: UUID
    ) -> [WorkoutGroupEntity] {
        (groupsByWorkout[workoutId] ?? [])
            .sorted { $0.order < $1.order }
    }

    func sortedSets(
        for groupId: UUID
    ) -> [SetEntity] {
        (setsByGroup[groupId] ?? [])
            .sorted { $0.order < $1.order }
    }

    func exercise(
        for setId: UUID
    ) -> ExerciseEntity? {
        exerciseBySet[setId]
    }

    func exerciseCount(for workoutId: UUID) -> Int {
        let groups = groupsByWorkout[workoutId] ?? []
        var seen = Set<UUID>()
        for group in groups {
            for set in setsByGroup[group.id] ?? [] {
                if let ex = exerciseBySet[set.id] {
                    seen.insert(ex.id)
                }
            }
        }
        return seen.count
    }

    func totalVolume(for workoutId: UUID) -> Double {
        let groups = groupsByWorkout[workoutId] ?? []
        var total = 0.0
        for group in groups {
            for set in setsByGroup[group.id] ?? [] {
                total += set.volume
            }
        }
        return total
    }

    func exerciseName(
        for groupId: UUID
    ) -> String? {
        guard
            let firstSet = sortedSets(
                for: groupId
            ).first,
            let exercise = exerciseBySet[
                firstSet.id
            ]
        else {
            return nil
        }
        return exercise.name
    }

    func exerciseNames(
        for workoutId: UUID
    ) -> String {
        let groups = sortedGroups(for: workoutId)
        var seen = Set<UUID>()
        var names: [String] = []
        for group in groups {
            for set in sortedSets(for: group.id) {
                if let exercise = exerciseBySet[set.id],
                   seen.insert(exercise.id).inserted {
                    names.append(exercise.name)
                }
            }
        }
        return names.joined(separator: ", ")
    }

    func allSetsFlattened(
        for workoutId: UUID
    ) -> [(group: WorkoutGroupEntity, set: SetEntity)] {
        sortedGroups(for: workoutId).flatMap { group in
            sortedSets(for: group.id)
                .map { (group: group, set: $0) }
        }
    }

    func completionProgress(
        for workoutId: UUID
    ) -> Double {
        let all = allSetsFlattened(
            for: workoutId
        )
        guard !all.isEmpty else { return 1.0 }
        let completed = all.filter {
            completedSetIds.contains($0.set.id)
        }.count
        return Double(completed)
            / Double(all.count)
    }

    func isSetCompleted(_ setId: UUID) -> Bool {
        completedSetIds.contains(setId)
    }

    func isWorkoutCompleted(
        _ workoutId: UUID
    ) -> Bool {
        completedWorkoutIds.contains(workoutId)
    }
}

// MARK: - BatchTraversal

struct BatchTraversal {
    /// Avoids per-entity SwiftData queries by resolving
    /// all relationships in ~6 batch fetches.
    @MainActor static func workoutSubgraph(
        workoutIds: [UUID],
        in context: ModelContext
    ) -> WorkoutSubgraph {
        guard !workoutIds.isEmpty else {
            return WorkoutSubgraph(
                groupsByWorkout: [:],
                setsByGroup: [:],
                exerciseBySet: [:],
                completedSetIds: [],
                completedWorkoutIds: []
            )
        }

        // 1. WorkoutGroups joins
        let wIds = workoutIds
        let wgJoins = context.fetchOrEmpty(
            FetchDescriptor<WorkoutGroups>(
                predicate: #Predicate {
                    wIds.contains($0.workoutId)
                }
            )
        )

        // 2. Group entities
        let groupIds = wgJoins.map(\.groupId)
        let groups = context.fetchOrEmpty(
            FetchDescriptor<WorkoutGroupEntity>(
                predicate: #Predicate {
                    groupIds.contains($0.id)
                }
            )
        )
        let groupMap = Dictionary(
            groups.map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        // 3. GroupSets joins
        let gsJoins = context.fetchOrEmpty(
            FetchDescriptor<GroupSets>(
                predicate: #Predicate {
                    groupIds.contains($0.groupId)
                }
            )
        )

        // 4. Set entities
        let setIds = gsJoins.map(\.setId)
        let sets = context.fetchOrEmpty(
            FetchDescriptor<SetEntity>(
                predicate: #Predicate {
                    setIds.contains($0.id)
                }
            )
        )
        let setMap = Dictionary(
            sets.map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        // 5. ExerciseSets joins
        let esJoins = context.fetchOrEmpty(
            FetchDescriptor<ExerciseSets>(
                predicate: #Predicate {
                    setIds.contains($0.setId)
                }
            )
        )

        // 6. Exercise entities
        let exerciseIds = esJoins.map(\.exerciseId)
        let exercises = context.fetchOrEmpty(
            FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate {
                    exerciseIds.contains($0.id)
                }
            )
        )
        let exerciseMap = Dictionary(
            exercises.map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        // O(1) lookups avoid repeated linear scans
        var groupsByWorkout:
            [UUID: [WorkoutGroupEntity]] = [:]
        for join in wgJoins {
            if let group = groupMap[join.groupId] {
                groupsByWorkout[
                    join.workoutId, default: []
                ].append(group)
            }
        }

        var setsByGroup: [UUID: [SetEntity]] = [:]
        for join in gsJoins {
            if let set = setMap[join.setId] {
                setsByGroup[join.groupId, default: []].append(set)
            }
        }

        var exerciseBySet:
            [UUID: ExerciseEntity] = [:]
        for join in esJoins {
            exerciseBySet[join.setId] =
                exerciseMap[join.exerciseId]
        }

        // 7. Set completions
        let setCompletions = context.fetchOrEmpty(
            FetchDescriptor<SetCompletions>(
                predicate: #Predicate {
                    setIds.contains($0.setId)
                }
            )
        )
        let completedSetIds = Set(
            setCompletions.map(\.setId)
        )

        // 8. Workout completions
        let workoutCompletions =
            context.fetchOrEmpty(
                FetchDescriptor<
                    WorkoutCompletions
                >(
                    predicate: #Predicate {
                        wIds.contains(
                            $0.workoutId
                        )
                    }
                )
            )
        let completedWorkoutIds = Set(
            workoutCompletions.map(\.workoutId)
        )

        return WorkoutSubgraph(
            groupsByWorkout: groupsByWorkout,
            setsByGroup: setsByGroup,
            exerciseBySet: exerciseBySet,
            completedSetIds: completedSetIds,
            completedWorkoutIds:
                completedWorkoutIds
        )
    }

    /// Batch-fetch workouts for multiple identities.
    /// Returns [identityId: [WorkoutEntity]].
    @MainActor static func workoutsByIdentity(
        identityIds: [UUID],
        in context: ModelContext
    ) -> [UUID: [WorkoutEntity]] {
        guard !identityIds.isEmpty else { return [:] }

        let ids = identityIds
        let joins = context.fetchOrEmpty(
            FetchDescriptor<IdentityWorkouts>(
                predicate: #Predicate {
                    ids.contains($0.identityId)
                }
            )
        )

        let workoutIds = joins.map(\.workoutId)
        let workouts = context.fetchOrEmpty(
            FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate {
                    workoutIds.contains($0.id)
                }
            )
        )
        let workoutMap = Dictionary(
            workouts.map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        var result: [UUID: [WorkoutEntity]] = [:]
        for join in joins {
            if let w = workoutMap[join.workoutId] {
                result[
                    join.identityId, default: []
                ].append(w)
            }
        }
        return result
    }

    /// Returns exercise IDs used across all workouts
    /// for an identity, querying only join tables.
    /// ~5-6 queries total regardless of data size
    /// (vs N+1 entity traversal).
    @MainActor static func exerciseIdsUsed(
        for identity: IdentityEntity,
        in context: ModelContext
    ) -> Set<UUID> {
        let workoutIds = identity
            .workouts(in: context).map(\.id)
        guard !workoutIds.isEmpty else { return [] }

        let wIds = workoutIds
        let wgJoins = context.fetchOrEmpty(
            FetchDescriptor<WorkoutGroups>(
                predicate: #Predicate {
                    wIds.contains($0.workoutId)
                }
            )
        )
        let groupIds = wgJoins.map(\.groupId)
        guard !groupIds.isEmpty else { return [] }

        let gsJoins = context.fetchOrEmpty(
            FetchDescriptor<GroupSets>(
                predicate: #Predicate {
                    groupIds.contains($0.groupId)
                }
            )
        )
        let setIds = gsJoins.map(\.setId)
        guard !setIds.isEmpty else { return [] }

        let esJoins = context.fetchOrEmpty(
            FetchDescriptor<ExerciseSets>(
                predicate: #Predicate {
                    setIds.contains($0.setId)
                }
            )
        )

        return Set(esJoins.map(\.exerciseId))
    }

    /// Batch-fetch the most recent completed set for
    /// each exercise, for a given identity.
    @MainActor static func lastSets(
        for identity: IdentityEntity,
        exerciseIds: [UUID],
        in context: ModelContext
    ) -> [UUID: SetEntity] {
        guard !exerciseIds.isEmpty else { return [:] }

        let completedWorkouts = identity
            .completedWorkouts(in: context)
        guard !completedWorkouts.isEmpty else { return [:] }

        let subgraph = workoutSubgraph(
            workoutIds: completedWorkouts.map(\.id),
            in: context
        )
        var result: [UUID: SetEntity] = [:]

        // Walk workouts in reverse-chronological order
        // (completedWorkouts already sorted newest-first)
        for workout in completedWorkouts {
            let groups = subgraph
                .sortedGroups(for: workout.id)
            for group in groups {
                let sets = subgraph
                    .sortedSets(for: group.id)
                for set in sets {
                    if let exercise = subgraph
                        .exerciseBySet[set.id],
                       exerciseIds
                        .contains(exercise.id),
                       result[exercise.id] == nil {
                        result[exercise.id] = set
                    }
                }
            }
            // Stop early if we found all exercises
            if result.count == exerciseIds.count {
                break
            }
        }
        return result
    }
}
