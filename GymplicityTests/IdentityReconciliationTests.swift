import XCTest
import SwiftData
@testable import Gymplicity

final class IdentityReconciliationTests: XCTestCase {

    // MARK: - createAlias

    func testCreateAliasInsertsRow() throws {
        let ctx = try makeTestContext()
        let a = UUID()
        let b = UUID()

        IdentityReconciliation.createAlias(id1: a, id2: b, in: ctx)

        let rows = try ctx.fetch(FetchDescriptor<IdentityAliases>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.identityId1, a)
        XCTAssertEqual(rows.first?.identityId2, b)
    }

    func testCreateAliasSelfIsNoOp() throws {
        let ctx = try makeTestContext()
        let a = UUID()

        IdentityReconciliation.createAlias(id1: a, id2: a, in: ctx)

        let rows = try ctx.fetch(FetchDescriptor<IdentityAliases>())
        XCTAssert(rows.isEmpty)
    }

    func testCreateAliasDuplicateSkipped() throws {
        let ctx = try makeTestContext()
        let a = UUID()
        let b = UUID()

        IdentityReconciliation.createAlias(id1: a, id2: b, in: ctx)
        IdentityReconciliation.createAlias(id1: a, id2: b, in: ctx)

        let rows = try ctx.fetch(FetchDescriptor<IdentityAliases>())
        XCTAssertEqual(rows.count, 1)
    }

    func testCreateAliasReverseOrderDuplicateSkipped() throws {
        let ctx = try makeTestContext()
        let a = UUID()
        let b = UUID()

        IdentityReconciliation.createAlias(id1: a, id2: b, in: ctx)
        IdentityReconciliation.createAlias(id1: b, id2: a, in: ctx)

        let rows = try ctx.fetch(FetchDescriptor<IdentityAliases>())
        XCTAssertEqual(rows.count, 1)
    }

    // MARK: - aliasGroup

    func testAliasGroupNoAliasReturnsSelf() throws {
        let ctx = try makeTestContext()
        let a = UUID()

        let group = IdentityReconciliation.aliasGroup(for: a, in: ctx)

        XCTAssertEqual(group, [a])
    }

    func testAliasGroupSingleAlias() throws {
        let ctx = try makeTestContext()
        let a = UUID()
        let b = UUID()
        IdentityReconciliation.createAlias(id1: a, id2: b, in: ctx)

        let groupA = IdentityReconciliation.aliasGroup(for: a, in: ctx)
        let groupB = IdentityReconciliation.aliasGroup(for: b, in: ctx)

        XCTAssertEqual(groupA, [a, b])
        XCTAssertEqual(groupB, [a, b])
    }

    func testAliasGroupTransitiveChain() throws {
        let ctx = try makeTestContext()
        let a = UUID()
        let b = UUID()
        let c = UUID()
        IdentityReconciliation.createAlias(id1: a, id2: b, in: ctx)
        IdentityReconciliation.createAlias(id1: b, id2: c, in: ctx)

        let group = IdentityReconciliation.aliasGroup(for: a, in: ctx)

        XCTAssertEqual(group, [a, b, c])
    }

    func testAliasGroupDisjointSetsNotConnected() throws {
        let ctx = try makeTestContext()
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let d = UUID()
        IdentityReconciliation.createAlias(id1: a, id2: b, in: ctx)
        IdentityReconciliation.createAlias(id1: c, id2: d, in: ctx)

        let groupA = IdentityReconciliation.aliasGroup(for: a, in: ctx)

        XCTAssertEqual(groupA, [a, b])
        XCTAssertFalse(groupA.contains(c))
        XCTAssertFalse(groupA.contains(d))
    }

    // MARK: - Alias-aware traversal

    func testWorkoutsReturnedAcrossAliases() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let traineeA = ctx.makeTrainee(name: "Alex-A", trainer: trainer)
        let traineeB = IdentityEntity(name: "Alex-B", isTrainer: false)
        ctx.insert(traineeB)

        // Each identity has a workout
        ctx.makeWorkout(for: traineeA, isCompleted: true)
        ctx.makeWorkout(for: traineeB, isCompleted: true)

        // Before alias: each sees only their own
        XCTAssertEqual(traineeA.workouts(in: ctx).count, 1)
        XCTAssertEqual(traineeB.workouts(in: ctx).count, 1)

        // Create alias
        IdentityReconciliation.createAlias(id1: traineeA.id, id2: traineeB.id, in: ctx)

        // After alias: both see both workouts
        XCTAssertEqual(traineeA.workouts(in: ctx).count, 2)
        XCTAssertEqual(traineeB.workouts(in: ctx).count, 2)
    }

    func testCompletedWorkoutsAliasAware() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let traineeA = ctx.makeTrainee(name: "A", trainer: trainer)
        let traineeB = IdentityEntity(name: "B", isTrainer: false)
        ctx.insert(traineeB)
        ctx.makeWorkout(for: traineeA, isCompleted: true)
        ctx.makeWorkout(for: traineeB, isCompleted: true)
        ctx.makeWorkout(for: traineeB) // active, should not appear

        IdentityReconciliation.createAlias(id1: traineeA.id, id2: traineeB.id, in: ctx)

        XCTAssertEqual(traineeA.completedWorkouts(in: ctx).count, 2)
    }

    func testWithoutAliasOnlyOwnWorkouts() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        let traineeA = ctx.makeTrainee(name: "A", trainer: trainer)
        let traineeB = ctx.makeTrainee(name: "B", trainer: trainer)
        ctx.makeWorkout(for: traineeA)
        ctx.makeWorkout(for: traineeB)

        // No alias — each sees only their own
        XCTAssertEqual(traineeA.workouts(in: ctx).count, 1)
        XCTAssertEqual(traineeB.workouts(in: ctx).count, 1)
    }
}
