import SwiftUI
import SwiftData

// MARK: - ParsedQuery

struct ParsedQuery: Sendable {
    let positiveTerms: [String]
    let negativeTerms: [String]

    init(_ input: String) {
        var positive: [String] = []
        var negative: [String] = []
        let words = input.lowercased()
            .split(separator: " ")
            .map(String.init)
        for word in words {
            if word.hasPrefix("-") {
                let stripped = String(word.dropFirst())
                if !stripped.isEmpty {
                    negative.append(stripped)
                }
            } else {
                positive.append(word)
            }
        }
        self.positiveTerms = positive
        self.negativeTerms = negative
    }

    var isEmpty: Bool {
        positiveTerms.isEmpty && negativeTerms.isEmpty
    }
}

// MARK: - Levenshtein

enum Levenshtein {
    static func threshold(for length: Int) -> Int {
        switch length {
        case 0...3: return 0
        case 4...6: return 1
        default: return 2
        }
    }

    static func distance(
        _ a: String,
        _ b: String,
        limit: Int
    ) -> Int {
        let a = Array(a)
        let b = Array(b)
        let m = a.count
        let n = b.count
        if abs(m - n) > limit { return limit + 1 }
        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
                rowMin = min(rowMin, curr[j])
            }
            if rowMin > limit { return limit + 1 }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    static func matches(
        _ query: String,
        against candidate: String
    ) -> Bool {
        let t = threshold(for: query.count)
        if t == 0 {
            return candidate.contains(query)
        }
        let candidateWords = candidate
            .split(separator: " ")
            .map(String.init)
        for word in candidateWords {
            if distance(query, word, limit: t) <= t {
                return true
            }
        }
        if candidate.contains(query) { return true }
        let joined = candidateWords.joined()
        return distance(
            query, joined, limit: t
        ) <= t
    }
}

// MARK: - MatchReason

enum MatchReason: Hashable, Sendable {
    case exactName
    case alias(String)
    case primaryMuscle(String)
    case secondaryMuscle(String)
    case joint(String)
    case bodyRegion(String)

    var displayLabel: String {
        switch self {
        case .exactName: return "Name"
        case .alias(let s): return s
        case .primaryMuscle(let s): return s
        case .secondaryMuscle(let s): return s
        case .joint(let s): return s
        case .bodyRegion(let s): return s
        }
    }

    var pillColor: Color {
        switch self {
        case .exactName: return GymColors.energy
        case .alias: return GymColors.focus
        case .primaryMuscle: return GymColors.power
        case .secondaryMuscle: return GymColors.chalk
        case .joint: return GymColors.warning
        case .bodyRegion: return GymColors.secondaryText
        }
    }

    var score: Int {
        switch self {
        case .exactName: return 0
        case .alias: return 10
        case .primaryMuscle: return 20
        case .secondaryMuscle: return 30
        case .joint: return 40
        case .bodyRegion: return 50
        }
    }
}

// MARK: - Result Types

struct UserExerciseResult: Identifiable {
    let exercise: ExerciseEntity
    let score: Int
    var id: UUID { exercise.id }
}

struct CatalogSearchResult: Identifiable, Sendable {
    let exercise: CatalogExercise
    let reasons: [MatchReason]
    let score: Int
    var id: String { exercise.id }
}

struct ExerciseSearchResults {
    let userExercises: [UserExerciseResult]
    let catalogExercises: [CatalogSearchResult]
}

// MARK: - ExerciseSearchEngine

final class ExerciseSearchEngine: @unchecked Sendable {
    private let indexedCatalog:
        [IndexedCatalogExercise]
    private let catalogById:
        [String: CatalogExercise]

    init() {
        guard let url = Bundle.main.url(
            forResource: "exercises",
            withExtension: "json"
        ) else {
            fatalError(
                "exercises.json missing from bundle"
            )
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            fatalError(
                "exercises.json unreadable:"
                    + " \(error)"
            )
        }
        let exercises: [CatalogExercise]
        do {
            exercises = try JSONDecoder()
                .decode(
                    [CatalogExercise].self,
                    from: data
                )
        } catch {
            fatalError(
                "exercises.json malformed:"
                    + " \(error)"
            )
        }
        indexedCatalog = exercises
            .map { IndexedCatalogExercise($0) }
        catalogById = Dictionary(
            uniqueKeysWithValues: exercises
                .map { ($0.id, $0) }
        )
    }

    func catalogExercise(
        forCatalogId id: String
    ) -> CatalogExercise? {
        catalogById[id]
    }

    func search(
        query: String,
        userExercises: [ExerciseEntity],
        recentlyUsedIDs: Set<UUID>
    ) -> ExerciseSearchResults {
        let parsed = ParsedQuery(query)

        let userResults = searchUserExercises(
            parsed,
            exercises: userExercises,
            recentlyUsedIDs: recentlyUsedIDs
        )

        if parsed.isEmpty {
            return ExerciseSearchResults(
            userExercises: userResults,
            catalogExercises: []
        )
        }

        let catalogResults = searchCatalog(
            parsed,
            excludingNames: Set(
                userExercises
                    .map { $0.name.lowercased() }
            )
        )

        return ExerciseSearchResults(
            userExercises: userResults,
            catalogExercises: catalogResults
        )
    }

    private func searchUserExercises(
        _ query: ParsedQuery,
        exercises: [ExerciseEntity],
        recentlyUsedIDs: Set<UUID>
    ) -> [UserExerciseResult] {
        if query.isEmpty {
            return exercises
                .sorted { a, b in
                    let aRecent = recentlyUsedIDs.contains(a.id)
                    let bRecent = recentlyUsedIDs.contains(b.id)
                    if aRecent != bRecent { return aRecent }
                    return a.name < b.name
                }
                .map {
                    UserExerciseResult(
                        exercise: $0,
                        score: recentlyUsedIDs
                            .contains($0.id) ? 0 : 1
                    )
                }
        }

        return exercises.compactMap { exercise in
            let name = exercise.name.lowercased()

            for neg in query.negativeTerms {
                if Levenshtein.matches(
                    neg, against: name
                ) {
                    return nil
                }
            }

            for pos in query.positiveTerms {
                if !Levenshtein.matches(
                    pos, against: name
                ) {
                    return nil
                }
            }

            let isExact = name == query.positiveTerms
                .joined(separator: " ")
            let exactBonus = isExact ? 0 : 1
            return UserExerciseResult(
                exercise: exercise,
                score: exactBonus
            )
        }
        .sorted {
            $0.score < $1.score
                || ($0.score == $1.score
                    && $0.exercise.name
                        < $1.exercise.name)
        }
    }

    private func searchCatalog(
        _ query: ParsedQuery,
        excludingNames: Set<String>
    ) -> [CatalogSearchResult] {
        return indexedCatalog.compactMap { indexed in
            let name = indexed.exercise.name
                .lowercased()
            if excludingNames.contains(name) {
                return nil
            }

            for neg in query.negativeTerms {
                if indexed.searchBlob.contains(neg) {
                    return nil
                }
            }

            var allReasons: [MatchReason] = []

            for term in query.positiveTerms {
                let reasons = matchTerm(
                    term, against: indexed
                )
                if reasons.isEmpty {
                    return nil
                }
                allReasons.append(
                    contentsOf: reasons
                )
            }

            let uniqueReasons = Array(Set(allReasons))
                .sorted { $0.score < $1.score }
            guard let bestScore = uniqueReasons
                .map(\.score).min()
            else {
                assertionFailure(
                    "unreachable: empty reasons"
                )
                return nil
            }
            return CatalogSearchResult(
                exercise: indexed.exercise,
                reasons: uniqueReasons,
                score: bestScore
            )
        }
        .sorted {
            $0.score < $1.score
                || ($0.score == $1.score
                    && $0.exercise.name
                        < $1.exercise.name)
        }
    }

    private func matchTerm(
        _ term: String,
        against indexed: IndexedCatalogExercise
    ) -> [MatchReason] {
        var reasons: [MatchReason] = []

        if indexed.nameWords.contains(where: {
            Levenshtein.matches(term, against: $0)
        }) {
            reasons.append(.exactName)
        }

        if indexed.aliasWords.contains(where: {
            Levenshtein.matches(term, against: $0)
        }) {
            if let matchedAlias = indexed.exercise
                .aliases.first(where: {
                    Levenshtein.matches(
                        term,
                        against: $0.lowercased()
                    )
                })
            {
                reasons.append(
                    .alias(matchedAlias)
                )
            }
        }

        for word in indexed.primaryMuscleWords {
            if Levenshtein.matches(
                term, against: word
            ) {
                if let name = indexed.exercise
                    .primaryMuscles.first(where: {
                        $0.lowercased().contains(word)
                    })
                {
                    reasons.append(
                        .primaryMuscle(name)
                    )
                }
            }
        }

        for word in indexed.secondaryMuscleWords {
            if Levenshtein.matches(
                term, against: word
            ) {
                if let name = indexed.exercise
                    .secondaryMuscles
                    .first(where: {
                        $0.lowercased().contains(word)
                    })
                {
                    reasons.append(
                        .secondaryMuscle(name)
                    )
                }
            }
        }

        for word in indexed.jointWords {
            if Levenshtein.matches(
                term, against: word
            ) {
                if let name = indexed.exercise
                    .joints.first(where: {
                        $0.lowercased().contains(word)
                    })
                {
                    reasons.append(.joint(name))
                }
            }
        }

        for word in indexed.regionWords {
            if Levenshtein.matches(
                term, against: word
            ) {
                if let name = indexed.exercise
                    .bodyRegions.first(where: {
                        $0.lowercased().contains(word)
                    })
                {
                    reasons.append(
                        .bodyRegion(name)
                    )
                }
            }
        }

        return reasons
    }
}

// MARK: - Environment Key

import SwiftUI

private struct ExerciseSearchEngineKey:
    EnvironmentKey
{
    static let defaultValue = ExerciseSearchEngine()
}

extension EnvironmentValues {
    var exerciseSearchEngine: ExerciseSearchEngine {
        get { self[ExerciseSearchEngineKey.self] }
        set {
            self[ExerciseSearchEngineKey.self] = newValue
        }
    }
}
