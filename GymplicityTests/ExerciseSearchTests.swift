import XCTest
import SwiftData
@testable import Gymplicity

final class LevenshteinTests: XCTestCase {
    func testIdenticalStrings() {
        XCTAssertEqual(Levenshtein.distance("squat", "squat", limit: 3), 0)
    }

    func testSingleInsertion() {
        XCTAssertEqual(Levenshtein.distance("squat", "squats", limit: 3), 1)
    }

    func testSingleDeletion() {
        XCTAssertEqual(Levenshtein.distance("squats", "squat", limit: 3), 1)
    }

    func testSingleSubstitution() {
        XCTAssertEqual(Levenshtein.distance("squat", "squit", limit: 3), 1)
    }

    func testTransposition() {
        XCTAssertEqual(Levenshtein.distance("squat", "sqaut", limit: 3), 2)
    }

    func testEarlyExitExceedsLimit() {
        let d = Levenshtein.distance("abc", "xyz", limit: 1)
        XCTAssertGreaterThan(d, 1)
    }

    func testEmptyStrings() {
        XCTAssertEqual(Levenshtein.distance("", "", limit: 3), 0)
        XCTAssertEqual(Levenshtein.distance("abc", "", limit: 5), 3)
        XCTAssertEqual(Levenshtein.distance("", "abc", limit: 5), 3)
    }

    func testLengthDifferenceExceedsLimit() {
        let d = Levenshtein.distance("a", "abcde", limit: 2)
        XCTAssertGreaterThan(d, 2)
    }

    func testThresholdForShortWords() {
        XCTAssertEqual(Levenshtein.threshold(for: 1), 0)
        XCTAssertEqual(Levenshtein.threshold(for: 3), 0)
    }

    func testThresholdForMediumWords() {
        XCTAssertEqual(Levenshtein.threshold(for: 4), 1)
        XCTAssertEqual(Levenshtein.threshold(for: 6), 1)
    }

    func testThresholdForLongWords() {
        XCTAssertEqual(Levenshtein.threshold(for: 7), 2)
        XCTAssertEqual(Levenshtein.threshold(for: 12), 2)
    }

    func testMatchesExactSubstring() {
        XCTAssertTrue(Levenshtein.matches("bench", against: "bench press"))
    }

    func testMatchesFuzzy() {
        XCTAssertTrue(Levenshtein.matches("benchpres", against: "bench press"))
    }

    func testShortQueryRequiresExact() {
        XCTAssertFalse(Levenshtein.matches("ab", against: "cd"))
        XCTAssertTrue(Levenshtein.matches("ab", against: "ab"))
    }

    func testMatchesPrefix() {
        XCTAssertTrue(Levenshtein.matches("squ", against: "squat"))
    }

    func testNoMatchForDistantStrings() {
        XCTAssertFalse(Levenshtein.matches("zzzzz", against: "squat"))
    }
}

final class ParsedQueryTests: XCTestCase {
    func testSimpleTokens() {
        let q = ParsedQuery("bench press")
        XCTAssertEqual(q.positiveTokens, ["bench", "press"])
        XCTAssertTrue(q.negativeTokens.isEmpty)
    }

    func testNegation() {
        let q = ParsedQuery("back !delts")
        XCTAssertEqual(q.positiveTokens, ["back"])
        XCTAssertEqual(q.negativeTokens, ["delts"])
    }

    func testMultipleNegations() {
        let q = ParsedQuery("curl !cable !machine")
        XCTAssertEqual(q.positiveTokens, ["curl"])
        XCTAssertEqual(q.negativeTokens, ["cable", "machine"])
    }

    func testEmptyQuery() {
        let q = ParsedQuery("")
        XCTAssertTrue(q.isEmpty)
    }

    func testOnlyNegation() {
        let q = ParsedQuery("!delts")
        XCTAssertTrue(q.positiveTokens.isEmpty)
        XCTAssertEqual(q.negativeTokens, ["delts"])
        XCTAssertFalse(q.isEmpty)
    }

    func testBangAloneIgnored() {
        let q = ParsedQuery("squat !")
        XCTAssertEqual(q.positiveTokens, ["squat"])
        XCTAssertTrue(q.negativeTokens.isEmpty)
    }

    func testCaseInsensitive() {
        let q = ParsedQuery("BENCH Press")
        XCTAssertEqual(q.positiveTokens, ["bench", "press"])
    }
}

final class MatchReasonTests: XCTestCase {
    func testScoreOrdering() {
        XCTAssertLessThan(MatchReason.exactName.score, MatchReason.alias("x").score)
        XCTAssertLessThan(MatchReason.alias("x").score, MatchReason.primaryMuscle("x").score)
        XCTAssertLessThan(MatchReason.primaryMuscle("x").score, MatchReason.secondaryMuscle("x").score)
        XCTAssertLessThan(MatchReason.secondaryMuscle("x").score, MatchReason.joint("x").score)
        XCTAssertLessThan(MatchReason.joint("x").score, MatchReason.bodyRegion("x").score)
    }

    func testDisplayLabels() {
        XCTAssertEqual(MatchReason.exactName.displayLabel, "Name")
        XCTAssertEqual(MatchReason.primaryMuscle("biceps").displayLabel, "biceps")
    }
}

final class ExerciseSearchEngineTests: XCTestCase {
    func testCatalogLoads() {
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "squat", userExercises: [])
        XCTAssertFalse(results.catalogExercises.isEmpty, "Catalog should have squat exercises")
    }

    func testEmptyQueryReturnsNoCalatog() {
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "", userExercises: [])
        XCTAssertTrue(results.catalogExercises.isEmpty)
    }

    func testFuzzyTypoMatch() {
        let engine = ExerciseSearchEngine.shared
        // "squatt" is 6 chars (threshold=1), distance to "squat" = 1
        let results = engine.search(query: "squatt", userExercises: [])
        let names = results.catalogExercises.map(\.exercise.name)
        XCTAssertTrue(names.contains(where: { $0.lowercased().contains("squat") }),
                       "Typo 'squatt' should fuzzy-match squat exercises")
    }

    func testMuscleSearch() {
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "biceps", userExercises: [])
        XCTAssertFalse(results.catalogExercises.isEmpty, "Should find exercises targeting biceps")
        let hasBicepsReason = results.catalogExercises.first?.reasons.contains(where: {
            if case .primaryMuscle = $0 { return true }
            if case .secondaryMuscle = $0 { return true }
            return false
        })
        XCTAssertTrue(hasBicepsReason == true)
    }

    func testBodyRegionSearch() {
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "legs", userExercises: [])
        XCTAssertFalse(results.catalogExercises.isEmpty, "Should find leg exercises")
    }

    func testNegationExcludes() {
        let engine = ExerciseSearchEngine.shared
        let all = engine.search(query: "back", userExercises: [])
        let filtered = engine.search(query: "back !legs", userExercises: [])
        XCTAssertLessThan(filtered.catalogExercises.count, all.catalogExercises.count,
                          "Negation should reduce results")
    }

    func testNameMatchRanksHigherThanMuscle() {
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "squat", userExercises: [])
        guard results.catalogExercises.count >= 2 else { return }
        let first = results.catalogExercises[0]
        let hasNameMatch = first.reasons.contains(.exactName)
        XCTAssertTrue(hasNameMatch, "Top result for 'squat' should have a name match")
    }

    func testMultiTokenANDLogic() {
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "biceps curl", userExercises: [])
        for result in results.catalogExercises {
            let blob = result.exercise.name.lowercased() +
                result.exercise.aliases.joined(separator: " ") +
                result.exercise.primaryMuscles.joined(separator: " ") +
                result.exercise.secondaryMuscles.joined(separator: " ")
            let hasBiceps = blob.contains("bicep")
            let hasCurl = blob.contains("curl")
            XCTAssertTrue(hasBiceps && hasCurl,
                          "\(result.exercise.name) should match both 'biceps' and 'curl'")
        }
    }

    func testCatalogExcludesUserExercises() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        ctx.makeExercise(name: "Barbell Back Squat", trainer: trainer)
        try ctx.save()

        let userExercises = trainer.exerciseCatalog(in: ctx)
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "squat", userExercises: userExercises)

        let catalogNames = results.catalogExercises.map(\.exercise.name)
        XCTAssertFalse(catalogNames.contains("Barbell Back Squat"),
                       "Catalog should not include exercises that exist in user's list")
        XCTAssertEqual(results.userExercises.count, 1)
    }

    func testUserExerciseFuzzyMatch() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        ctx.makeExercise(name: "Bench Press", trainer: trainer)
        ctx.makeExercise(name: "Overhead Press", trainer: trainer)
        try ctx.save()

        let userExercises = trainer.exerciseCatalog(in: ctx)
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "bench", userExercises: userExercises)

        XCTAssertEqual(results.userExercises.count, 1)
        XCTAssertEqual(results.userExercises.first?.exercise.name, "Bench Press")
    }

    func testEmptyQueryReturnsAllUserExercises() throws {
        let ctx = try makeTestContext()
        let trainer = ctx.makeTrainer()
        ctx.makeExercise(name: "Squat", trainer: trainer)
        ctx.makeExercise(name: "Bench", trainer: trainer)
        try ctx.save()

        let userExercises = trainer.exerciseCatalog(in: ctx)
        let engine = ExerciseSearchEngine.shared
        let results = engine.search(query: "", userExercises: userExercises)

        XCTAssertEqual(results.userExercises.count, 2)
        XCTAssertTrue(results.catalogExercises.isEmpty)
    }
}
