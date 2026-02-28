# Gymplicity Data Schema

![Entity-Relationship Diagram](schema.svg)

## Entities

### Trainer

The root entity. Represents the person operating the app.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | String | Display name |

**Relationships:**

- `trainees` &rarr; **[Trainee]** &mdash; One-to-many. Delete rule: **cascade** (deleting a trainer deletes all their trainees).
- `exerciseDefinitions` &rarr; **[ExerciseDefinition]** &mdash; One-to-many. Delete rule: **cascade** (deleting a trainer deletes their entire exercise catalog).

### ExerciseDefinition

A named exercise in the trainer's catalog. Identity is UUID-based, so renaming
an exercise definition propagates to every exercise that references it.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | String | Human-readable name (e.g. "Bench Press") |
| trainer | Trainer? | Foreign key to owning Trainer |

**Relationships:**

- `trainer` &rarr; **Trainer?** &mdash; Many-to-one. Inverse of `Trainer.exerciseDefinitions`.
- `exercises` &rarr; **[Exercise]** &mdash; One-to-many. Delete rule: **nullify** (deleting an exercise definition sets `Exercise.definition` to nil rather than destroying workout history).

### Trainee

A person being trained. Belongs to exactly one Trainer.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | String | Display name |
| trainer | Trainer? | Foreign key to owning Trainer |

**Relationships:**

- `trainer` &rarr; **Trainer?** &mdash; Many-to-one. Inverse of `Trainer.trainees`.
- `workouts` &rarr; **[Workout]** &mdash; One-to-many. Delete rule: **cascade** (deleting a trainee deletes all their workouts).

### Workout

A single training workout for one trainee. Created when the trainer taps
"Start", closed when they tap "End Workout" (which sets `isComplete = true`).

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| trainee | Trainee? | Foreign key to owning Trainee |
| date | Date | Timestamp when the workout was created |
| notes | String? | Optional free-form workout notes |
| isComplete | Bool | False while active, true once ended |

**Relationships:**

- `trainee` &rarr; **Trainee?** &mdash; Many-to-one. Inverse of `Trainee.workouts`.
- `exercises` &rarr; **[Exercise]** &mdash; One-to-many, ordered by `Exercise.order`. Delete rule: **cascade**.

**Computed properties:**

- `totalVolume: Double` &mdash; Sum of `exercises.totalVolume`.
- `exerciseCount: Int` &mdash; Count of exercises.

### Exercise

One exercise performed within a workout. Acts as the join between a Workout and
an ExerciseDefinition, carrying the ordering position and owning the collection of sets.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| workout | Workout? | Foreign key to owning Workout |
| definition | ExerciseDefinition? | Foreign key to the exercise catalog entry |
| order | Int | Position of this exercise within the workout (0-based) |

**Relationships:**

- `workout` &rarr; **Workout?** &mdash; Many-to-one. Inverse of `Workout.exercises`.
- `definition` &rarr; **ExerciseDefinition?** &mdash; Many-to-one. Inverse of `ExerciseDefinition.exercises`.
- `sets` &rarr; **[WorkoutSet]** &mdash; One-to-many, ordered by `WorkoutSet.order`. Delete rule: **cascade**.

**Computed properties:**

- `name: String` &mdash; `definition?.name ?? "Unknown"`.
- `totalVolume: Double` &mdash; Sum of `sets.volume`.

### WorkoutSet

A single set within an exercise: one weight-at-reps data point,
individually timestamped on completion.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| exercise | Exercise? | Foreign key to owning Exercise |
| order | Int | Position of this set within the exercise (0-based) |
| weight | Double | Weight lifted, in the user's preferred unit |
| reps | Int | Number of repetitions |
| isCompleted | Bool | Whether the trainer has marked this set done |
| completedAt | Date? | Timestamp when the set was marked complete; nil if not yet completed |

**Relationships:**

- `exercise` &rarr; **Exercise?** &mdash; Many-to-one. Inverse of `Exercise.sets`.

**Computed properties:**

- `volume: Double` &mdash; `weight * reps`.

## Relationship Summary

```
Trainer  1──*  ExerciseDefinition  (cascade)
Trainer  1──*  Trainee             (cascade)
Trainee  1──*  Workout             (cascade)
Workout  1──*  Exercise            (cascade)
ExerciseDefinition 1──*  Exercise  (nullify)
Exercise 1──*  WorkoutSet          (cascade)
```

All primary keys are client-generated UUIDs. All foreign keys are optional
(`?`) at the Swift type level because SwiftData represents inverse
relationships as optionals, but in practice every entity is created with its
parent relationship set.

## Delete Rule Rationale

- **Cascade** is used down the ownership chain (Trainer &rarr; Trainee &rarr;
  Workout &rarr; Exercise &rarr; WorkoutSet) so that deleting a parent
  cleanly removes all children.
- **Nullify** is used for ExerciseDefinition &rarr; Exercise so that removing an
  exercise definition from the catalog does not destroy historical workout data. The
  exercise remains with `definition = nil`, and `name` returns "Unknown".
