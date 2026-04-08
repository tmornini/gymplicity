# Gymplicity

Trainer-first iOS gym tracking app. SwiftUI, SwiftData, Swift Charts. iOS 17+.

## Build & Test

```bash
build/simulate     # build for iOS Simulator
build/device       # build and install on connected iPhone
build/distribute   # archive for distribution (Release)
build/test         # run tests on iOS Simulator
```

Tests are part of the build flow. Code must build, function properly,
and pass tests at each commit. Run `build/test` before pushing.

### Device Setup

```bash
build/device YOUR_TEAM_ID    # pass Apple Team ID as argument
```

## Architecture

- See CHURCH-OF-CODE.md and follow the strictures
- See VISION.md for vision and screen architecture
- See SCHEMA.md for full data model documentation

### Entities (5)

IdentityEntity, ExerciseEntity, WorkoutEntity, WorkoutGroupEntity, SetEntity

### Join Tables (8)

TrainerTrainees, TrainerExercises, IdentityWorkouts, WorkoutGroups,
GroupSets, ExerciseSets, TemplateInstances, PairedDevices

### Views (13)

HomeView, ActiveWorkoutView, SetEntryView, AddExerciseView, ProfileView,
ProgressChartsView, AddTraineeView, WorkoutHistoryView, TemplateListView,
TemplateEditorView, StartFromTemplateView, GuidedWorkoutView, SyncView

### Theme Module (8 files in Gymplicity/Theme/)

GymColors, GymFont, GymMetrics, GymModifiers, MascotView,
AnimatedMascotView, GymProgressBar, Weight

- **Mascot "Lifty":** Bathroom-sign stick figure (Path strokes, round caps). 10 poses, 6 animations. 27 appearances across the app.
- **Palette:** iron/steel/chalk/rubber + energy orange, power green, focus blue
- **Typography:** SF Pro Rounded throughout, monospaced digits for numbers

### Sync Module (5 files in Gymplicity/Sync/)

SyncPayload, SyncEngine, SyncSessionManager, SyncTrigger, IdentityReconciliation

- **SyncPayload:** Codable DTOs mirroring all entities/joins + payload builder
- **SyncEngine:** Idempotent role-based PUT merge (INSERT IF NOT EXISTS by UUID)
- **SyncSessionManager:** Multipeer Connectivity lifecycle (advertise/browse/connect/send)
- **IdentityReconciliation:** First-time pairing UUID rewrite (trainer's UUID wins)

## Conventions

- `is` prefix for Bool properties (isTrainer, isCompleted, isTemplate, isSuperset)
- Entity postfix on all @Model classes (IdentityEntity, not Identity)
- Relationship traversal via extension methods on entities, not stored properties
- Cascade deletes down ownership chain; nullify for ExerciseSets
- Computed properties (volume, exerciseCount) derived from traversal, never stored

## Verb Semantics

This app uses HTTP verb semantics (PUT/GET/DELETE), not CRUD:
- **PUT:** Resources placed at client-generated UUIDs. SyncEngine implements PUT — role-based merge. Join tables use PUT (insert if not already present).
- **GET:** All traversal methods (entity extensions that take ModelContext)
- **DELETE:** Cascade deletes down ownership chain

## Rules

- Gymplicity target uses PBXFileSystemSynchronizedRootGroup — new files in Gymplicity/ auto-compile, no project file edits needed
- All relationship queries take a ModelContext parameter
- Keep join tables as plain @Model classes with UUID pairs only
