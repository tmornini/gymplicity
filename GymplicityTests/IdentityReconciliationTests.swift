import XCTest
import SwiftData
@testable import Gymplicity

final class IdentityReconciliationTests: XCTestCase {

    func testIdentityUUIDRewritten() throws {
        let ctx = try makeTestContext()
        let trainee = ctx.makeTrainee(name: "Alex", trainer: ctx.makeTrainer())
        let oldId = trainee.id
        let newId = UUID()

        IdentityReconciliation.rewriteIdentity(from: oldId, to: newId, in: ctx)

        XCTAssertEqual(trainee.id, newId)
    }

    func testIdentityWorkoutsUpdatedForMatchingRows() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(name: "Alex", trainer: trainer)
        let oldId = trainee.id
        let newId = UUID()
        ctx.makeWorkout(for: trainee)

        IdentityReconciliation.rewriteIdentity(from: oldId, to: newId, in: ctx)

        let iwJoins = try ctx.fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.identityId == newId }
        ))
        XCTAssertEqual(iwJoins.count, 1)

        // Old ID should have no joins
        let oldJoins = try ctx.fetch(FetchDescriptor<IdentityWorkouts>(
            predicate: #Predicate { $0.identityId == oldId }
        ))
        XCTAssert(oldJoins.isEmpty)
    }

    func testTrainerTraineesUpdatedForMatchingRows() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(name: "Alex", trainer: trainer)
        let oldId = trainee.id
        let newId = UUID()

        IdentityReconciliation.rewriteIdentity(from: oldId, to: newId, in: ctx)

        let ttJoins = try ctx.fetch(FetchDescriptor<TrainerTrainees>(
            predicate: #Predicate { $0.traineeId == newId }
        ))
        XCTAssertEqual(ttJoins.count, 1)
        XCTAssertEqual(ttJoins.first?.trainerId, trainer.id)
    }

    func testSameIdIsNoOp() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(name: "Alex", trainer: trainer)
        let id = trainee.id

        IdentityReconciliation.rewriteIdentity(from: id, to: id, in: ctx)

        // Identity unchanged
        XCTAssertEqual(trainee.id, id)
        XCTAssertEqual(trainee.name, "Alex")
    }

    func testIdentityNotFoundLocallyCompletesWithoutCrash() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let trainee = ctx.makeTrainee(name: "Alex", trainer: trainer)
        let oldId = trainee.id
        let newId = UUID()
        let missingId = UUID()

        // Rewrite from an ID that has no matching IdentityEntity
        // but trainee's joins reference oldId, not missingId
        IdentityReconciliation.rewriteIdentity(from: missingId, to: newId, in: ctx)

        // Trainee entity unchanged
        XCTAssertEqual(trainee.id, oldId)
        // No crash — test passes if we get here
    }
}
