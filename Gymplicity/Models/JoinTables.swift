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
    var lastSyncDate: Date?

    init(localIdentityId: UUID, remoteIdentityId: UUID, remoteName: String) {
        self.localIdentityId = localIdentityId
        self.remoteIdentityId = remoteIdentityId
        self.remoteName = remoteName
        self.lastSyncDate = nil
    }
}
