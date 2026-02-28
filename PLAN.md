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

```
Trainer
├── id: UUID
├── name: String
├── trainees: [Trainee]
└── exerciseDefinitions: [ExerciseDefinition]  (the trainer's exercise catalog)

ExerciseDefinition
├── id: UUID
├── name: String
├── trainer: Trainer
└── exercises: [Exercise]           (all exercises using this definition)

Trainee
├── id: UUID
├── name: String
├── trainer: Trainer
└── workouts: [Workout]

Workout
├── id: UUID
├── trainee: Trainee
├── date: Date
├── notes: String?
├── isComplete: Bool
└── exercises: [Exercise]

Exercise
├── id: UUID
├── workout: Workout
├── definition: ExerciseDefinition  (reference to the exercise catalog entry)
├── order: Int                      (exercise ordering within workout)
└── sets: [WorkoutSet]

WorkoutSet
├── id: UUID
├── exercise: Exercise
├── order: Int                      (set ordering within exercise)
├── weight: Double                  (in user's preferred unit)
├── reps: Int
├── isCompleted: Bool
└── completedAt: Date?              (timestamp when set was completed)
```

### Derived Values (computed, not stored)

- **Per-set volume**: `weight × reps`
- **Per-exercise volume**: sum of all set volumes
- **Per-workout volume**: sum of all exercise volumes
- **Per-rep weight for exercise**: `weight` at a given `reps` value over time (matched by exercise definition name)
- **Total volume for exercise**: sum of all set volumes for that exercise over time (matched by exercise definition name)

---

## Screen Architecture

### 1. Trainer Home (root)

The primary landing screen. Shows the trainer's active trainees and
provides quick access to start or resume workouts.

```
┌─────────────────────────────┐
│  Gymplicity          [gear] │
│─────────────────────────────│
│                             │
│  Active Workouts            │
│  ┌───────────────────────┐  │
│  │ 🟢 Alex M. - Chest    │  │
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

The core trainer-operation screen. Must be fast and minimal-tap.

```
┌─────────────────────────────┐
│ ← Alex M.      [End Workout]│
│  Feb 28, 2026                │
│──────────────────────────────│
│                              │
│  Bench Press            [+] │
│  ┌──────────────────────┐   │
│  │ Set 1: 135 lb × 10 ✓│   │
│  │ Set 2: 155 lb × 8  ✓│   │
│  │ Set 3: 155 lb × 7  ✓│   │
│  │ [+ Add Set]          │   │
│  └──────────────────────┘   │
│                              │
│  Incline DB Press       [+] │
│  ┌──────────────────────┐   │
│  │ Set 1: 50 lb × 12  ✓│   │
│  │ Set 2: __ lb × __   │   │
│  │ [+ Add Set]          │   │
│  └──────────────────────┘   │
│                              │
│  [+ Add Exercise]            │
└──────────────────────────────┘
```

**Key interactions:**
- Tap weight or reps to edit inline (number pad)
- Tap checkmark to toggle set completion
- Swipe set to delete
- Previous workout values shown as placeholders/suggestions
- Add exercise by typing name (autocomplete from previously used names)

### 3. Set Entry (inline / sheet)

Quick data entry optimized for speed:

```
┌─────────────────────────────┐
│  Bench Press - Set 3        │
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

Accessible per-trainee and per-exercise definition. Two chart types:

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

### 5. Trainee Profile

Overview of a trainee's history and trends.

```
┌──────────────────────────────┐
│ ← Alex M.            [Edit] │
│──────────────────────────────│
│                              │
│  Recent Workouts             │
│    Feb 28 - Chest (4 ex)     │
│    Feb 26 - Back (5 ex)      │
│    Feb 24 - Legs (4 ex)      │
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
- Data model implementation (all `@Model` classes)
- Basic navigation shell (TabView or NavigationStack)

### Phase 2: Trainer Workout Flow (core value)
- Trainer home screen with trainee list
- Start/resume workout for a trainee
- Active workout view with exercise list
- Add exercises by name (autocomplete from history)
- Set entry: weight × reps with inline editing
- Set completion toggling
- Show previous workout values as reference
- End workout

### Phase 3: Visualization
- Per-exercise progress view
- Chart A: per-rep weight over time (Swift Charts)
- Chart B: total volume over time (Swift Charts)
- Trainee profile with workout history
- Drill-down from trainee → exercise → charts

### Phase 4: Polish
- Exercise reordering within workout (drag & drop)
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
   from the trainee's last workout for that exercise. The trainer adjusts
   rather than entering from scratch.

3. **Multi-trainee aware** — A trainer may have 2-3 trainees at once in a
   group workout. Quick trainee switching from the home screen, with each
   workout maintaining independent state.

4. **Progressive disclosure** — The workout screen is simple by default.
   Charts and history are one tap away but never in the way.
