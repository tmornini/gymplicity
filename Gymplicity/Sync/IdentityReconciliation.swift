import Foundation
import SwiftData

struct IdentityReconciliation {
    /// Rewrites a trainee's local identity UUID to match the trainer's version.
    /// Updates the IdentityEntity itself and all join table rows referencing the old UUID.
    ///
    /// Trainer's UUID wins (trainer-first app). Call this on the trainee's device
    /// when pairing for the first time.
    static func rewriteIdentity(from oldId: UUID, to newId: UUID, in context: ModelContext) {
        guard oldId != newId else { return }

        // 1. Update the IdentityEntity itself
        if let identity = (try? context.fetch(FetchDescriptor<IdentityEntity>(
            predicate: #Predicate { $0.id == oldId }
        )))?.first {
            identity.id = newId
        }

        // 2. Update IdentityWorkouts rows where identityId == oldId
        let iwJoins = (try? context.fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.identityId == oldId }
        ))) ?? []
        for join in iwJoins {
            join.identityId = newId
        }

        // 3. Update TrainerTrainees rows where traineeId == oldId
        let ttJoins = (try? context.fetch(FetchDescriptor<TrainerTrainees>(
            predicate: #Predicate { $0.traineeId == oldId }
        ))) ?? []
        for join in ttJoins {
            join.traineeId = newId
        }
    }
}
