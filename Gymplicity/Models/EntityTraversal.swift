import Foundation
import SwiftData

// MARK: - IdentityEntity Traversal

extension IdentityEntity {
    @MainActor func trainees(
        in context: ModelContext
    ) -> [IdentityEntity] {
        let id = self.id
        let joins = context.fetchOrDie(
            FetchDescriptor<TrainerTrainees>(
                predicate: #Predicate {
                    $0.trainerId == id
                }
            )
        )
        let ids = joins.map(\.traineeId)
        return context.fetchOrDie(
            FetchDescriptor<IdentityEntity>(
                predicate: #Predicate {
                    ids.contains($0.id)
                }
            )
        )
    }

    @MainActor func trainer(
        in context: ModelContext
    ) -> IdentityEntity? {
        let id = self.id
        guard let join = context.fetchFirst(
            FetchDescriptor<TrainerTrainees>(
                predicate: #Predicate {
                    $0.traineeId == id
                }
            )
        ) else { return nil }
        let trainerId = join.trainerId
        return context.fetchFirst(
            FetchDescriptor<IdentityEntity>(
                predicate: #Predicate {
                    $0.id == trainerId
                }
            )
        )
    }

    @MainActor func exercises(
        in context: ModelContext
    ) -> [ExerciseEntity] {
        let id = self.id
        let joins = context.fetchOrDie(
            FetchDescriptor<TrainerExercises>(
                predicate: #Predicate {
                    $0.trainerId == id
                }
            )
        )
        let ids = joins.map(\.exerciseId)
        return context.fetchOrDie(
            FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate {
                    ids.contains($0.id)
                }
            )
        )
    }

    @MainActor func exerciseCatalog(
        in context: ModelContext
    ) -> [ExerciseEntity] {
        if isTrainer {
            return exercises(in: context)
                .sorted { $0.name < $1.name }
        }
        if let trainer = trainer(in: context) {
            return trainer
                .exercises(in: context)
                .sorted { $0.name < $1.name }
        }
        return exercises(in: context)
            .sorted { $0.name < $1.name }
    }

    @MainActor func workouts(
        in context: ModelContext
    ) -> [WorkoutEntity] {
        let aliasIds = Array(
            IdentityReconciliation.aliasGroup(
                for: self.id,
                in: context
            )
        )
        let joins = context.fetchOrDie(
            FetchDescriptor<IdentityWorkouts>(
                predicate: #Predicate {
                    aliasIds.contains($0.identityId)
                }
            )
        )
        let ids = joins.map(\.workoutId)
        return context.fetchOrDie(
            FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate {
                    ids.contains($0.id)
                }
            )
        )
    }

    @MainActor func activeWorkouts(
        in context: ModelContext
    ) -> [WorkoutEntity] {
        workouts(in: context).filter {
            !$0.isCompleted(in: context)
                && !$0.isTemplate
        }
    }

    @MainActor func completedWorkouts(
        in context: ModelContext
    ) -> [WorkoutEntity] {
        workouts(in: context)
            .filter {
                $0.isCompleted(in: context)
                    && !$0.isTemplate
            }
            .sorted { $0.date > $1.date }
    }

    @MainActor func templates(
        in context: ModelContext
    ) -> [WorkoutEntity] {
        workouts(in: context)
            .filter { $0.isTemplate }
            .sorted {
                switch (
                    $0.templateName(in: context),
                    $1.templateName(in: context)
                ) {
                case let (.some(a), .some(b)):
                    a < b
                case (.some, .none): true
                case (.none, .some): false
                case (.none, .none): false
                }
            }
    }

    @MainActor func exercisesUsed(
        in context: ModelContext
    ) -> [ExerciseEntity] {
        let sets = workouts(in: context).flatMap {
            $0.groups(in: context).flatMap {
                $0.sets(in: context)
            }
        }
        let exercisesByID = Dictionary(
            sets.compactMap {
                $0.exercise(in: context)
            }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return exercisesByID.values
            .sorted { $0.name < $1.name }
    }

    @MainActor func lastSet(
        for exercise: ExerciseEntity,
        in context: ModelContext
    ) -> SetEntity? {
        completedWorkouts(in: context)
            .flatMap {
                $0.sortedGroups(in: context)
                    .flatMap {
                        $0.sortedSets(in: context)
                    }
            }
            .first {
                $0.exercise(in: context)?.id
                    == exercise.id
            }
    }

    @MainActor func history(
        for exercise: ExerciseEntity,
        in context: ModelContext
    ) -> [(date: Date, set: SetEntity)] {
        completedWorkouts(in: context)
            .reversed()
            .flatMap { workout in
                workout.groups(in: context)
                    .flatMap { $0.sets(in: context) }
                    .filter {
                        $0.exercise(in: context)?.id
                            == exercise.id
                    }
                    .map {
                        (date: workout.date, set: $0)
                    }
            }
    }

    @MainActor func findOrCreateExercise(
        named name: String,
        in context: ModelContext
    ) -> ExerciseEntity {
        let catalog = exercises(in: context)
        if let existing = catalog.first(where: {
            $0.name.lowercased()
                == name.lowercased()
        }) {
            return existing
        }
        let exercise = ExerciseEntity(
            name: name,
            catalogId: nil
        )
        context.insert(exercise)
        let join = TrainerExercises(
            trainerId: self.id,
            exerciseId: exercise.id
        )
        context.insert(join)
        return exercise
    }
}

// MARK: - WorkoutEntity Traversal

extension WorkoutEntity {
    @MainActor func templateName(
        in context: ModelContext
    ) -> String? {
        let id = self.id
        return context.fetchFirst(
            FetchDescriptor<WorkoutTemplate>(
                predicate: #Predicate {
                    $0.workoutId == id
                }
            )
        )?.name
    }

    @MainActor func notes(
        in context: ModelContext
    ) -> String? {
        let id = self.id
        return context.fetchFirst(
            FetchDescriptor<WorkoutNotes>(
                predicate: #Predicate {
                    $0.workoutId == id
                }
            )
        )?.notes
    }

    @MainActor func owner(
        in context: ModelContext
    ) -> IdentityEntity {
        let id = self.id
        guard let join = context.fetchFirst(
            FetchDescriptor<IdentityWorkouts>(
                predicate: #Predicate {
                    $0.workoutId == id
                }
            )
        ) else {
            fatalError(
                "WorkoutEntity \(id) has no"
                + " IdentityWorkouts join"
            )
        }
        let identityId = join.identityId
        guard let owner = context.fetchFirst(
            FetchDescriptor<IdentityEntity>(
                predicate: #Predicate {
                    $0.id == identityId
                }
            )
        ) else {
            fatalError(
                "WorkoutEntity \(id) owner"
                + " \(identityId) not found"
            )
        }
        return owner
    }

    @MainActor func groups(
        in context: ModelContext
    ) -> [WorkoutGroupEntity] {
        let id = self.id
        let joins = context.fetchOrDie(
            FetchDescriptor<WorkoutGroups>(
                predicate: #Predicate {
                    $0.workoutId == id
                }
            )
        )
        let ids = joins.map(\.groupId)
        return context.fetchOrDie(
            FetchDescriptor<WorkoutGroupEntity>(
                predicate: #Predicate {
                    ids.contains($0.id)
                }
            )
        )
    }

    @MainActor func sortedGroups(
        in context: ModelContext
    ) -> [WorkoutGroupEntity] {
        groups(in: context)
            .sorted { $0.order < $1.order }
    }

    @MainActor func nextGroupOrder(
        in context: ModelContext
    ) -> Int {
        let orders = groups(in: context).map(\.order)
        guard let maxOrder = orders.max() else {
            return 0
        }
        return maxOrder + 1
    }

    @MainActor func totalVolume(
        in context: ModelContext
    ) -> Double {
        groups(in: context).reduce(0) {
            $0 + $1.totalVolume(in: context)
        }
    }

    @MainActor func exerciseCount(
        in context: ModelContext
    ) -> Int {
        let allSets = groups(in: context)
            .flatMap { $0.sets(in: context) }
        let uniqueIDs = Swift.Set(
            allSets.compactMap {
                $0.exercise(in: context)?.id
            }
        )
        return uniqueIDs.count
    }

    // MARK: - Guided Workout Helpers

    @MainActor func allSetsFlattened(
        in context: ModelContext
    ) -> [(
        group: WorkoutGroupEntity,
        set: SetEntity
    )] {
        sortedGroups(in: context).flatMap {
            group in
            group.sortedSets(in: context)
                .map { (group: group, set: $0) }
        }
    }

    @MainActor func firstIncompleteSetIndex(
        in context: ModelContext
    ) -> Int? {
        allSetsFlattened(in: context)
            .firstIndex {
                !$0.set.isCompleted(in: context)
            }
    }

    @MainActor func nextIncompleteSetIndex(
        after index: Int,
        in context: ModelContext
    ) -> Int? {
        let all = allSetsFlattened(in: context)
        if let found = all.dropFirst(index + 1)
            .indices
            .first(where: {
                !all[$0].set
                    .isCompleted(in: context)
            }) {
            return found
        }
        return all.prefix(index).indices
            .first(where: {
                !all[$0].set
                    .isCompleted(in: context)
            })
    }

    @MainActor func markCompleted(
        in context: ModelContext
    ) {
        context.insert(
            WorkoutCompletions(
                workoutId: id,
                completedAt: .now
            )
        )
        SyncTrigger.entityUpdated(
            .workout,
            id: id
        )
    }

    @MainActor func template(
        in context: ModelContext
    ) -> WorkoutEntity? {
        let id = self.id
        guard let join = context.fetchFirst(
            FetchDescriptor<TemplateInstances>(
                predicate: #Predicate {
                    $0.workoutId == id
                }
            )
        ) else { return nil }
        let templateId = join.templateId
        return context.fetchFirst(
            FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate {
                    $0.id == templateId
                }
            )
        )
    }

    @MainActor func exerciseNames(
        in context: ModelContext
    ) -> String {
        let allSets = sortedGroups(in: context)
            .flatMap {
                $0.sortedSets(in: context)
            }
        var seen = Swift.Set<UUID>()
        var names: [String] = []
        for set in allSets {
            if let exercise =
                set.exercise(in: context),
                seen.insert(exercise.id).inserted
            {
                names.append(exercise.name)
            }
        }
        return names.joined(separator: ", ")
    }

    @MainActor func completionProgress(
        in context: ModelContext
    ) -> Double {
        let all = allSetsFlattened(in: context)
        guard !all.isEmpty else { return 1.0 }
        let completed = all.filter {
            $0.set.isCompleted(in: context)
        }.count
        return Double(completed)
            / Double(all.count)
    }

    @MainActor func isCompleted(
        in context: ModelContext
    ) -> Bool {
        let id = self.id
        return context.fetchFirst(
            FetchDescriptor<WorkoutCompletions>(
                predicate: #Predicate {
                    $0.workoutId == id
                }
            )
        ) != nil
    }
}

// MARK: - WorkoutGroupEntity Traversal

extension WorkoutGroupEntity {
    @MainActor func workout(
        in context: ModelContext
    ) -> WorkoutEntity {
        let id = self.id
        guard let join = context.fetchFirst(
            FetchDescriptor<WorkoutGroups>(
                predicate: #Predicate {
                    $0.groupId == id
                }
            )
        ) else {
            fatalError(
                "WorkoutGroupEntity \(id)"
                + " has no WorkoutGroups join"
            )
        }
        let workoutId = join.workoutId
        guard let workout = context.fetchFirst(
            FetchDescriptor<WorkoutEntity>(
                predicate: #Predicate {
                    $0.id == workoutId
                }
            )
        ) else {
            fatalError(
                "WorkoutGroupEntity \(id)"
                + " workout \(workoutId)"
                + " not found"
            )
        }
        return workout
    }

    @MainActor func sets(
        in context: ModelContext
    ) -> [SetEntity] {
        let id = self.id
        let joins = context.fetchOrDie(
            FetchDescriptor<GroupSets>(
                predicate: #Predicate {
                    $0.groupId == id
                }
            )
        )
        let ids = joins.map(\.setId)
        return context.fetchOrDie(
            FetchDescriptor<SetEntity>(
                predicate: #Predicate {
                    ids.contains($0.id)
                }
            )
        )
    }

    @MainActor func sortedSets(
        in context: ModelContext
    ) -> [SetEntity] {
        sets(in: context)
            .sorted { $0.order < $1.order }
    }

    @MainActor func nextSetOrder(
        in context: ModelContext
    ) -> Int {
        let orders = sets(in: context).map(\.order)
        guard let maxOrder = orders.max() else {
            return 0
        }
        return maxOrder + 1
    }

    @MainActor func totalVolume(
        in context: ModelContext
    ) -> Double {
        sets(in: context)
            .reduce(0) { $0 + $1.volume }
    }

    @MainActor func exerciseName(
        in context: ModelContext
    ) -> String? {
        sortedSets(in: context)
            .first?
            .exercise(in: context)?
            .name
    }
}

// MARK: - SetEntity Traversal

extension SetEntity {
    @MainActor func isCompleted(
        in context: ModelContext
    ) -> Bool {
        let id = self.id
        return context.fetchFirst(
            FetchDescriptor<SetCompletions>(
                predicate: #Predicate {
                    $0.setId == id
                }
            )
        ) != nil
    }

    @MainActor func completedAt(
        in context: ModelContext
    ) -> Date? {
        let id = self.id
        return context.fetchFirst(
            FetchDescriptor<SetCompletions>(
                predicate: #Predicate {
                    $0.setId == id
                }
            )
        )?.completedAt
    }

    @MainActor func exercise(
        in context: ModelContext
    ) -> ExerciseEntity? {
        let id = self.id
        guard let join = context.fetchFirst(
            FetchDescriptor<ExerciseSets>(
                predicate: #Predicate {
                    $0.setId == id
                }
            )
        ) else { return nil }
        let exerciseId = join.exerciseId
        return context.fetchFirst(
            FetchDescriptor<ExerciseEntity>(
                predicate: #Predicate {
                    $0.id == exerciseId
                }
            )
        )
    }

    @MainActor func group(
        in context: ModelContext
    ) -> WorkoutGroupEntity {
        let id = self.id
        guard let join = context.fetchFirst(
            FetchDescriptor<GroupSets>(
                predicate: #Predicate {
                    $0.setId == id
                }
            )
        ) else {
            fatalError(
                "SetEntity \(id) has no"
                + " GroupSets join"
            )
        }
        let groupId = join.groupId
        guard let group = context.fetchFirst(
            FetchDescriptor<WorkoutGroupEntity>(
                predicate: #Predicate {
                    $0.id == groupId
                }
            )
        ) else {
            fatalError(
                "SetEntity \(id) group"
                + " \(groupId) not found"
            )
        }
        return group
    }
}
