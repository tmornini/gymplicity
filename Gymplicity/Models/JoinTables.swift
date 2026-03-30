import Foundation
import SwiftData

// MARK: - Join Tables

@Model
final class TrainerTrainees {
    var trainerId: UUID
    var traineeId: UUID

    init(trainerId: UUID, traineeId: UUID) {
        self.trainerId = trainerId
        self.traineeId = traineeId
    }
}

@Model
final class TrainerExercises {
    var trainerId: UUID
    var exerciseId: UUID

    init(trainerId: UUID, exerciseId: UUID) {
        self.trainerId = trainerId
        self.exerciseId = exerciseId
    }
}

@Model
final class IdentityWorkouts {
    var identityId: UUID
    var workoutId: UUID

    init(identityId: UUID, workoutId: UUID) {
        self.identityId = identityId
        self.workoutId = workoutId
    }
}

@Model
final class WorkoutGroups {
    var workoutId: UUID
    var groupId: UUID

    init(workoutId: UUID, groupId: UUID) {
        self.workoutId = workoutId
        self.groupId = groupId
    }
}

@Model
final class GroupSets {
    var groupId: UUID
    var setId: UUID

    init(groupId: UUID, setId: UUID) {
        self.groupId = groupId
        self.setId = setId
    }
}

@Model
final class ExerciseSets {
    var exerciseId: UUID
    var setId: UUID

    init(exerciseId: UUID, setId: UUID) {
        self.exerciseId = exerciseId
        self.setId = setId
    }
}

@Model
final class TemplateInstances {
    var templateId: UUID
    var workoutId: UUID

    init(templateId: UUID, workoutId: UUID) {
        self.templateId = templateId
        self.workoutId = workoutId
    }
}

@Model
final class IdentityAliases {
    var identityId1: UUID
    var identityId2: UUID

    init(identityId1: UUID, identityId2: UUID) {
        self.identityId1 = identityId1
        self.identityId2 = identityId2
    }
}

@Model
final class PairedDevices {
    var localIdentityId: UUID
    var remoteIdentityId: UUID
    var remoteName: String

    init(
        localIdentityId: UUID,
        remoteIdentityId: UUID,
        remoteName: String
    ) {
        self.localIdentityId = localIdentityId
        self.remoteIdentityId = remoteIdentityId
        self.remoteName = remoteName
    }
}

@Model
final class WorkoutTemplate {
    var workoutId: UUID
    var name: String

    init(workoutId: UUID, name: String) {
        self.workoutId = workoutId
        self.name = name
    }
}

// MARK: - Event Tables

@Model
final class SetCompletions {
    var setId: UUID
    var completedAt: Date

    init(setId: UUID, completedAt: Date) {
        self.setId = setId
        self.completedAt = completedAt
    }
}

@Model
final class WorkoutCompletions {
    var workoutId: UUID
    var completedAt: Date

    init(
        workoutId: UUID,
        completedAt: Date
    ) {
        self.workoutId = workoutId
        self.completedAt = completedAt
    }
}

@Model
final class DeviceSyncEvents {
    var localIdentityId: UUID
    var remoteIdentityId: UUID
    var syncedAt: Date

    init(
        localIdentityId: UUID,
        remoteIdentityId: UUID,
        syncedAt: Date
    ) {
        self.localIdentityId = localIdentityId
        self.remoteIdentityId = remoteIdentityId
        self.syncedAt = syncedAt
    }
}
