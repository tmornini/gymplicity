# Gymplicity - iOS Gym Tracking App

## Vision

A trainer-first iOS app for tracking weight x reps across exercises for
multiple trainees, with progress visualization. Optimized for fast,
mid-session operation — a trainer glancing at their phone between sets
should be able to log data in seconds.

---

## Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| UI | SwiftUI | Modern, declarative, native iOS |
| Persistence | SwiftData | Apple's native ORM, iCloud-ready |
| Charts | Swift Charts | Native framework, tight SwiftUI integration |
| Min Target | iOS 17+ | SwiftData + Swift Charts maturity |
| Architecture | MVVM | Clean separation, testable, SwiftUI-natural |

No backend server. Local-first with SwiftData. iCloud sync can be
enabled later via CloudKit integration (SwiftData supports this
natively).

---

## Data Model

Entities hold only their own attributes — no foreign keys. All
relationships live in dedicated join tables storing pairs of UUIDs.

### Entities

```
IdentityEntity
├── id: UUID
├── name: String
└── isTrainer: Bool

ExerciseEntity
├── id: UUID
└── name: String

WorkoutEntity
├── id: UUID
├── date: Date
├── notes: String?
└── isComplete: Bool

SupersetEntity
├── id: UUID
└── order: Int

SetEntity
├── id: UUID
├── order: Int
├── weight: Double
├── reps: Int
├── isCompleted: Bool
└── completedAt: Date?
```

### Join Tables

```
TrainerTrainees       (trainerId, traineeId)
TrainerExercises      (trainerId, exerciseId)
IdentityWorkouts      (identityId, workoutId)
WorkoutSupersets      (workoutId, supersetId)
SupersetSets          (supersetId, setId)
ExerciseSets          (exerciseId, setId)
```

### Derived Values (computed, not stored)

- **Per-set volume**: `weight × reps`
- **Per-superset volume**: sum of all set volumes
- **Per-workout volume**: sum of all superset volumes
- **Per-rep weight for exercise**: `weight` at a given `reps` value over time (matched by exercise)
- **Total volume for exercise**: sum of all set volumes for that exercise over time

---

## Screen Architecture

### 1. Home (root)

The primary landing screen. On first launch, prompts the user to set up
their identity (name + trainer/trainee role). Trainers see their trainees
and active workouts; trainees see their own profile directly.

```
┌─────────────────────────────┐
│  Gymplicity          [gear] │
│─────────────────────────────│
│                             │
│  Active Workouts            │
│  ┌───────────────────────┐  │
│  │ 🟢 Alex M.            │  │
│  │    Started 25 min ago │  │
│  └───────────────────────┘  │
│                             │
│  Trainees                   │
│  ┌───────────────────────┐  │
│  │ Alex M.        [Start]│  │
│  │ Jamie R.       [Start]│  │
│  │ Sam K.         [Start]│  │
│  │ + Add Trainee         │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

### 2. Active Workout View

The core trainer-operation screen. Organized by superset — each superset
is a numbered section containing one or more sets (potentially of different
exercises for circuit training).

```
┌──────────────────────────────┐
│ ← Alex M.      [End Workout]│
│  Feb 28, 2026                │
│──────────────────────────────│
│                              │
│  Superset 1                  │
│  ┌──────────────────────┐   │
│  │ Bench  135 lb × 10 ✓│   │
│  │ Row     95 lb × 10 ✓│   │
│  │ [+ Add Set]          │   │
│  └──────────────────────┘   │
│                              │
│  Superset 2                  │
│  ┌──────────────────────┐   │
│  │ Bench  155 lb × 8  ✓│   │
│  │ Row    105 lb × 8    │   │
│  │ [+ Add Set]          │   │
│  └──────────────────────┘   │
│                              │
│  [+ Add Superset]            │
└──────────────────────────────┘
```

**Key interactions:**
- Tap weight or reps to edit via set entry sheet
- Tap checkmark to toggle set completion
- Swipe set to delete
- Previous workout values pre-filled as defaults
- Add set picks exercise by name (autocomplete from catalog)

### 3. Set Entry (sheet)

Quick data entry optimized for speed:

```
┌─────────────────────────────┐
│  Bench Press                 │
│──────────────────────────────│
│                              │
│  Weight        Reps          │
│  ┌────────┐   ┌────────┐    │
│  │  155   │   │   7    │    │
│  └────────┘   └────────┘    │
│                              │
│  Last time: 155 × 8         │
│                              │
│  [Done]                      │
└──────────────────────────────┘
```

### 4. Progress / Charts View

Accessible per-identity and per-exercise. Two chart types:

**Chart A: Per-Rep Weight Over Time**
- X-axis: date
- Y-axis: weight
- One line per rep count (e.g., "8-rep max", "5-rep max")
- Shows strength progression at specific rep ranges

**Chart B: Total Volume Over Time**
- X-axis: date
- Y-axis: total weight lifted (weight × reps, summed)
- Shows overall workload trends

```
┌──────────────────────────────┐
│ ← Alex M. > Bench Press     │
│──────────────────────────────│
│                              │
│  Weight @ Reps Over Time     │
│  ┌──────────────────────┐   │
│  │    ╱─── 5-rep         │   │
│  │  ╱─── 8-rep           │   │
│  │╱─── 10-rep            │   │
│  └──────────────────────┘   │
│                              │
│  Total Volume Over Time      │
│  ┌──────────────────────┐   │
│  │        ╱──            │   │
│  │    ╱──╱               │   │
│  │╱──╱                   │   │
│  └──────────────────────┘   │
│                              │
└──────────────────────────────┘
```

### 5. Profile

Overview of an identity's history and trends.

```
┌──────────────────────────────┐
│ ← Alex M.            [Edit] │
│──────────────────────────────│
│                              │
│  Recent Workouts             │
│    Feb 28 - 4 exercises      │
│    Feb 26 - 5 exercises      │
│    Feb 24 - 4 exercises      │
│                              │
│  Progress by Exercise        │
│    Bench Press →             │
│    Squat →                   │
│    Deadlift →                │
└──────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation
- Xcode project setup (SwiftUI, SwiftData, Swift Charts)
- Data model implementation (5 entities + 6 join tables)
- Basic navigation shell (NavigationStack)
- First-launch identity setup flow

### Phase 2: Workout Flow (core value)
- Home screen with trainee list (trainer) or profile (trainee)
- Start/resume workout
- Active workout view with superset sections
- Add sets by picking exercise (autocomplete from catalog)
- Set entry: weight × reps with inline editing
- Set completion toggling
- Show previous workout values as reference
- End workout

### Phase 3: Visualization
- Per-exercise progress view
- Chart A: per-rep weight over time (Swift Charts)
- Chart B: total volume over time (Swift Charts)
- Profile with workout history
- Drill-down from profile → exercise → charts

### Phase 4: Polish
- Set deletion (swipe)
- Workout notes
- Unit preference (lb / kg)
- Settings screen
- Seed/demo data for first launch
- App icon and launch screen

---

## Key Design Principles

1. **Speed over beauty** — A trainer mid-session needs 2-3 taps to log a
   set, not 5-6. Large tap targets, number pads, smart defaults.

2. **Previous values as defaults** — When starting a new workout, pre-fill
   from the last workout for that exercise. The trainer adjusts
   rather than entering from scratch.

3. **Multi-trainee aware** — A trainer may have 2-3 trainees at once in a
   group workout. Quick trainee switching from the home screen, with each
   workout maintaining independent state.

4. **Progressive disclosure** — The workout screen is simple by default.
   Charts and history are one tap away but never in the way.

5. **No foreign keys on entities** — All relationships live in dedicated
   join tables. Entities are pure data; relationships are explicit and
   portable to any backend.
