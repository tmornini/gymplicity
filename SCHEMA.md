# Gymplicity Data Schema

![Entity-Relationship Diagram](schema.svg)

## Design Principle

Entities hold only their own attributes &mdash; no foreign keys. All
relationships live in dedicated join tables that store only ID pairs.

## Entities

### IdentityEntity

A person using the app. The `isTrainer` flag determines role: a trainer
manages trainees and owns the exercise catalog; a trainee performs workouts.
On first launch the user picks their role.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | String | Display name |
| isTrainer | Bool | True for trainers, false for trainees |

### ExerciseEntity

A named exercise in the trainer's catalog (e.g. "Bench Press"). Identity
is UUID-based so renaming propagates everywhere.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | String | Human-readable name |

### WorkoutEntity

A single training session. Created on "Start", closed on "End Workout"
(sets `isComplete = true`).

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| date | Date | Timestamp when the workout was created |
| notes | String? | Optional free-form notes |
| isComplete | Bool | False while active, true once ended |

### SupersetEntity

A group of sets performed together within a workout. For straight sets
each superset contains one set; for circuits it contains multiple sets of
different exercises.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| order | Int | Position within the workout (0-based) |

### SetEntity

A single set: one exercise at a weight for reps, individually timestamped
on completion.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| order | Int | Position within the superset (0-based) |
| weight | Double | Weight lifted, in the user's preferred unit |
| reps | Int | Number of repetitions |
| isCompleted | Bool | Whether this set has been marked done |
| completedAt | Date? | Timestamp when marked complete; nil if pending |

**Computed:**

- `volume: Double` &mdash; `weight * reps`.

## Join Tables

All relationships are expressed through join-only tables storing pairs of
UUIDs. No foreign keys exist on any entity.

### TrainerTrainees

Links a trainer identity to the trainee identities they manage.

| Column | Type |
|--------|------|
| trainerId | UUID |
| traineeId | UUID |

### TrainerExercises

Links a trainer identity to the exercises in their catalog.

| Column | Type |
|--------|------|
| trainerId | UUID |
| exerciseId | UUID |

### IdentityWorkouts

Links an identity to the workouts they have performed.

| Column | Type |
|--------|------|
| identityId | UUID |
| workoutId | UUID |

### WorkoutSupersets

Links a workout to the supersets it contains.

| Column | Type |
|--------|------|
| workoutId | UUID |
| supersetId | UUID |

### SupersetSets

Links a superset to the sets it contains.

| Column | Type |
|--------|------|
| supersetId | UUID |
| setId | UUID |

### ExerciseSets

Links an exercise catalog entry to the sets that reference it.

| Column | Type |
|--------|------|
| exerciseId | UUID |
| setId | UUID |

## Relationship Semantics

| Join Table | Meaning | Delete Behavior |
|---|---|---|
| TrainerTrainees | Trainer manages these trainees | Cascade: delete trainer &rarr; delete trainees + data |
| TrainerExercises | Trainer owns these catalog entries | Cascade: delete trainer &rarr; delete exercises |
| IdentityWorkouts | Identity performed these workouts | Cascade: delete identity &rarr; delete workouts |
| WorkoutSupersets | Workout contains these supersets | Cascade: delete workout &rarr; delete supersets |
| SupersetSets | Superset contains these sets | Cascade: delete superset &rarr; delete sets |
| ExerciseSets | Sets reference this exercise | Nullify: delete exercise &rarr; remove join rows, sets remain |

## Computed Properties (not stored)

**IdentityEntity** (via ModelContext traversal):

- `exerciseCatalog` &mdash; own exercises if trainer, else trainer's exercises
- `activeWorkouts` &mdash; incomplete workouts
- `completedWorkouts` &mdash; completed workouts, newest first
- `allExercises` &mdash; unique exercises across all workouts
- `lastSet(for:)` &mdash; most recent completed set for a given exercise
- `history(for:)` &mdash; all sets for a given exercise, oldest first

**WorkoutEntity:**

- `totalVolume` &mdash; sum of all set volumes across all supersets
- `exerciseCount` &mdash; count of unique exercises across all sets

**SupersetEntity:**

- `totalVolume` &mdash; sum of all set volumes

## Delete Rule Rationale

- **Cascade** is used down the ownership chain (Identity &rarr; Workout
  &rarr; Superset &rarr; Set) so that deleting a parent cleanly removes
  all children and their join rows.
- **Nullify** is used for ExerciseSets so that removing an exercise from
  the catalog does not destroy historical workout data. The set remains;
  only the join row is removed.
