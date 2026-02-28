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
- `exercises` &rarr; **[Exercise]** &mdash; One-to-many. Delete rule: **cascade** (deleting a trainer deletes their entire exercise catalog).

### Exercise

A named exercise in the trainer's catalog. Identity is UUID-based, so renaming
an exercise propagates to every session entry that references it.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | String | Human-readable name (e.g. "Bench Press") |
| trainer | Trainer? | Foreign key to owning Trainer |

**Relationships:**

- `trainer` &rarr; **Trainer?** &mdash; Many-to-one. Inverse of `Trainer.exercises`.
- `entries` &rarr; **[SessionEntry]** &mdash; One-to-many. Delete rule: **nullify** (deleting an exercise sets `SessionEntry.exercise` to nil rather than destroying session history).

### Trainee

A person being trained. Belongs to exactly one Trainer.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | String | Display name |
| trainer | Trainer? | Foreign key to owning Trainer |

**Relationships:**

- `trainer` &rarr; **Trainer?** &mdash; Many-to-one. Inverse of `Trainer.trainees`.
- `sessions` &rarr; **[Session]** &mdash; One-to-many. Delete rule: **cascade** (deleting a trainee deletes all their sessions).

### Session

A single training session for one trainee. Created when the trainer taps
"Start", closed when they tap "End Session" (which sets `isComplete = true`).

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| trainee | Trainee? | Foreign key to owning Trainee |
| date | Date | Timestamp when the session was created |
| notes | String? | Optional free-form session notes |
| isComplete | Bool | False while active, true once ended |

**Relationships:**

- `trainee` &rarr; **Trainee?** &mdash; Many-to-one. Inverse of `Trainee.sessions`.
- `entries` &rarr; **[SessionEntry]** &mdash; One-to-many, ordered by `SessionEntry.order`. Delete rule: **cascade**.

**Computed properties:**

- `totalVolume: Double` &mdash; Sum of `entries.totalVolume`.
- `exerciseCount: Int` &mdash; Count of entries.

### SessionEntry

One exercise performed within a session. Acts as the join between a Session and
an Exercise, carrying the ordering position and owning the collection of sets.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| session | Session? | Foreign key to owning Session |
| exercise | Exercise? | Foreign key to the Exercise catalog entry |
| order | Int | Position of this exercise within the session (0-based) |

**Relationships:**

- `session` &rarr; **Session?** &mdash; Many-to-one. Inverse of `Session.entries`.
- `exercise` &rarr; **Exercise?** &mdash; Many-to-one. Inverse of `Exercise.entries`.
- `sets` &rarr; **[ExerciseSet]** &mdash; One-to-many, ordered by `ExerciseSet.order`. Delete rule: **cascade**.

**Computed properties:**

- `exerciseName: String` &mdash; `exercise?.name ?? "Unknown"`.
- `totalVolume: Double` &mdash; Sum of `sets.volume`.

### ExerciseSet

A single set within a session entry: one weight-at-reps data point,
individually timestamped on completion.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| entry | SessionEntry? | Foreign key to owning SessionEntry |
| order | Int | Position of this set within the entry (0-based) |
| weight | Double | Weight lifted, in the user's preferred unit |
| reps | Int | Number of repetitions |
| isCompleted | Bool | Whether the trainer has marked this set done |
| completedAt | Date? | Timestamp when the set was marked complete; nil if not yet completed |

**Relationships:**

- `entry` &rarr; **SessionEntry?** &mdash; Many-to-one. Inverse of `SessionEntry.sets`.

**Computed properties:**

- `volume: Double` &mdash; `weight * reps`.

## Relationship Summary

```
Trainer  1──*  Exercise      (cascade)
Trainer  1──*  Trainee       (cascade)
Trainee  1──*  Session       (cascade)
Session  1──*  SessionEntry  (cascade)
Exercise 1──*  SessionEntry  (nullify)
SessionEntry 1──*  ExerciseSet  (cascade)
```

All primary keys are client-generated UUIDs. All foreign keys are optional
(`?`) at the Swift type level because SwiftData represents inverse
relationships as optionals, but in practice every entity is created with its
parent relationship set.

## Delete Rule Rationale

- **Cascade** is used down the ownership chain (Trainer &rarr; Trainee &rarr;
  Session &rarr; SessionEntry &rarr; ExerciseSet) so that deleting a parent
  cleanly removes all children.
- **Nullify** is used for Exercise &rarr; SessionEntry so that removing an
  exercise from the catalog does not destroy historical session data. The
  session entry remains with `exercise = nil`, and `exerciseName` returns
  "Unknown".
