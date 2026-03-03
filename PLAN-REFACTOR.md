# Refactoring Plan

## Diagnosis

The codebase is ~4,800 lines across 37 Swift files. The architecture is
solid — join-table relationships, idempotent sync with role-based UPSERT,
change-driven delta sync, a clean design system — but the code has
accumulated copy-paste duplication and views that reach into the world
to find things instead of receiving them.

Recent additions (design system, change-driven sync, bidirectional UPSERT)
are well-structured. The duplication predates them and has grown.

---

## 1. Extract `formatWeight` — one function, not five copies

The identical function body appears in **5 files**: SetRow (ActiveWorkoutView
:251), SetEntryView:110, TemplateSetRow (TemplateEditorView:151),
ProfileView:149, WorkoutHistoryView:91, GuidedWorkoutView:270.

A second variant `formatWeightValue` (without "lb" suffix) appears in
**3 files**: SetEntryView:117, TemplateSetEntryView (TemplateEditorView:255),
GuidedWorkoutView:277.

**Change:** Add two static methods to a `Weight` enum (new file or in
Models.swift):

```swift
enum Weight {
    static func formatted(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value)) lb" : String(format: "%.1f lb", value)
    }
    static func rawValue(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
```

Delete all private `formatWeight` and `formatWeightValue` copies.

---

## 2. Extract `WeightRepsField` — one component, not three copies

SetEntryView:25-65, TemplateSetEntryView:182-222, and GuidedWorkoutView
:110-146 all build the same weight/reps text-field pair. Differences:

| | SetEntryView | TemplateSetEntryView | GuidedWorkoutView |
|---|---|---|---|
| Font | numericEntrySmall | numericEntrySmall | numericEntry |
| Accent color | energy | focus | energy |
| Width | 120 | 120 | 130 |

**Change:** Extract a `WeightRepsField` view:

```swift
struct WeightRepsField: View {
    @Binding var weightText: String
    @Binding var repsText: String
    var font: Font = GymFont.numericEntrySmall
    var accentColor: Color = GymColors.energy
    var fieldWidth: CGFloat = 120
    @FocusState.Binding var focusedField: Field?
    enum Field { case weight, reps }
}
```

Replace all three inline copies.

---

## 3. Extract `LastSetReference` — one view, not two copies

SetEntryView:68-76 and GuidedWorkoutView:192-203 both render a "Last
time" pill. The only difference is the pill color (focus vs steel).

**Change:** Extract:

```swift
struct LastSetReference: View {
    let set: SetEntity?
    var color: Color = GymColors.steel
}
```

---

## 4. Unify `SetRow` and `TemplateSetRow`

SetRow (ActiveWorkoutView:184-257) and TemplateSetRow (TemplateEditorView
:105-157) are structurally identical. Differences:

- SetRow: completion checkmark button + presents SetEntryView + `.setCompletion()`
- TemplateSetRow: target icon + presents TemplateSetEntryView

**Change:** Single `SetRowView` with a `mode: Mode` enum:

```swift
enum Mode { case workout(WorkoutEntity), template }
```

Mode controls trailing icon, tap-to-complete behavior, and which entry
sheet appears. Eliminates ~75 lines.

---

## 5. Unify `SetEntryView` and `TemplateSetEntryView`

SetEntryView (124 lines) and TemplateSetEntryView (TemplateEditorView:161
-261, 100 lines) are identical except:

- SetEntryView sets `isCompleted = true` and `completedAt = .now` on save
- SetEntryView shows a "Last time" reference
- TemplateSetEntryView shows a "Target" label and uses `focus` accent

**Change:** Merge into one `SetEntryView` with `previousSet: SetEntity? = nil`.
When `previousSet` is nil (template mode), skip completion logic and
last-time reference, show "Target" label, use `focus` accent. Delete
TemplateSetEntryView entirely.

After items 2-5, TemplateEditorView drops from 262 to ~100 lines.

---

## 6. Extract `exerciseNamesList` — one function, not two copies

ProfileView's WorkoutRow:189-198 and TemplateListView's TemplateRow:96-106
contain identical methods.

**Change:** Add to WorkoutEntity:

```swift
extension WorkoutEntity {
    func exerciseNames(in context: ModelContext) -> String { ... }
}
```

---

## 7. Extract mutations to `ModelContext` — don't scatter across views

Several mutation patterns are duplicated across views. Each should live on
`ModelContext` so the SyncTrigger call is centralized too:

| Mutation | Duplicated in | Proposed method |
|---|---|---|
| `startWorkout(for:)` | HomeView:153, ProfileView:140 | `ModelContext.startWorkout(for:)` |
| `addGroup(to:isSuperset:)` | ActiveWorkoutView:137, TemplateEditorView:85 | `ModelContext.addGroup(to:isSuperset:)` |
| `deleteSets(from:at:)` | ActiveWorkoutView:167, TemplateEditorView:94 | `ModelContext.deleteSets(from:at:)` |
| `endWorkout(_:)` | ActiveWorkoutView:175, GuidedWorkoutView:229 | `WorkoutEntity.end()` (fires SyncTrigger) |

Each method calls `SyncTrigger` internally, so callers don't have to
remember. Views become pure renderers.

---

## 8. Consolidate the superset/non-superset branch

ActiveWorkoutView:16-55 has two nearly-identical `Section` blocks. The
only differences: section header text ("Superset N" vs exercise name)
and whether "Add Set" opens AddExerciseView or calls `addSetToGroup`.

**Change:** One Section, conditional header, conditional add button:

```swift
Section {
    // shared ForEach + onDelete
    Button("Add Set") {
        if group.isSuperset {
            targetGroup = group; showingAddExercise = true
        } else {
            addSetToGroup(group)
        }
    }
} header: {
    Text(group.isSuperset ? "Superset \(group.order + 1)" : exerciseName(for: group))
}
```

Cuts ~15 lines.

---

## 9. Inject identity — don't fish for it via `@Query`

HomeView uses `@Query private var identities: [IdentityEntity]` then
`identities.first`. This is "select, don't inject" — the view reaches
into the database hoping exactly one identity exists.

**Change:** Lift identity resolution to `GymplicityApp`:

```swift
@main struct GymplicityApp: App {
    @State private var identity: IdentityEntity?

    var body: some Scene {
        WindowGroup {
            if let identity {
                HomeView(identity: identity)
            } else {
                SetupView(onComplete: { identity = $0 })
            }
        }
    }
}
```

HomeView receives its identity. No more `@Query`, no more `.first`.
The setup flow becomes explicit rather than hidden inside HomeView.

---

## 10. Remove `templateId` foreign key from `WorkoutEntity`

`WorkoutEntity.templateId: UUID?` is a foreign key referencing another
WorkoutEntity — violating the stated architecture rule that entities
hold only their own attributes and all relationships live in join tables.

**Change:** Create `TemplateInstances` join table:

```swift
@Model final class TemplateInstances {
    var templateId: UUID
    var workoutId: UUID
}
```

Remove `templateId` from WorkoutEntity. Update `instantiateTemplate`,
SyncPayload, and SyncEngine accordingly. Add to ModelContainer schema.

---

## 11. Deduplicate SyncEngine join-table merges

`SyncEngine.merge()` has 6 join-table loops (lines 178-254) that are
structurally identical: fetch by two-UUID predicate, insert if not exists.

The 5 entity loops have meaningfully different authority logic (sender-only
for identities, trainer-only for exercises/groups, either-side for
workouts/sets) — these should stay explicit.

**Change:** The join-table loops resist a Swift generic (because
`#Predicate` macros require concrete types). But we can still reduce
boilerplate — keep the 6 loops but extract the fetch-check into a
shared helper, or accept the repetition since each is only 10 lines
and the structure is obvious. This is the lowest-priority item.

---

## 12. Fix SyncPayloadBuilder N+1 queries

Lines 246-280 of SyncPayload.swift do nested for-each: for each workout
→ fetch groups; for each group → fetch sets; for each set → fetch
exercise joins. Classic N+1.

**Change:** Batch-fetch upfront:

```swift
let allWgJoins = fetch(WorkoutGroups where workoutId in allWorkoutIds)
let allGroupIds = allWgJoins.map(\.groupId)
let allGroups = fetch(WorkoutGroupEntity where id in allGroupIds)
let allGsJoins = fetch(GroupSets where groupId in allGroupIds)
// ... etc
```

Three flat fetches instead of O(workouts * groups * sets) nested fetches.

---

## 13. Delete deprecated `SyncEngine.put()` shim

Lines 259-263: `put()` just forwards to `merge()`. It's marked
`@available(*, deprecated)`. If nothing calls it, delete it.

---

## Execution Order

Mechanical extractions first (low risk, high reward), then structural:

| Phase | Items | Risk | Reduction |
|-------|-------|------|-----------|
| A. Shared utilities | 1, 2, 3 | Low | ~150 lines |
| B. Unify components | 4, 5, 6 | Low | ~180 lines |
| C. Centralize mutations | 7, 8 | Low | ~80 lines |
| D. Inject identity | 9 | Medium | clarity gain |
| E. Fix templateId FK | 10 | Medium | architectural fix |
| F. SyncEngine cleanup | 11, 12, 13 | Medium | ~40 lines + perf |

Each phase is independently shippable. Build and test after each.
