# Gymplicity

Trainer-first iOS gym tracking app. SwiftUI, SwiftData, Swift Charts. iOS 17+.

## Build & Test

```bash
build/simulate     # build for iOS Simulator
build/device       # build and install on connected iPhone
build/distribute   # archive for distribution (Release)
build/test         # run tests on iOS Simulator
```

### Device Setup

```bash
build/device YOUR_TEAM_ID    # pass Apple Team ID as argument
```

## Architecture

- **Entities hold only their own attributes — no foreign keys**
- All relationships live in join tables storing UUID pairs
- See PLAN.md for vision and screen architecture
- See SCHEMA.md for full data model documentation

### Entities (5)

IdentityEntity, ExerciseEntity, WorkoutEntity, WorkoutGroupEntity, SetEntity

### Join Tables (7)

TrainerTrainees, TrainerExercises, IdentityWorkouts, WorkoutGroups,
GroupSets, ExerciseSets, PairedDevices

### Views (13)

HomeView, ActiveWorkoutView, SetEntryView, AddExerciseView, ProfileView,
ProgressChartsView, AddTraineeView, WorkoutHistoryView, TemplateListView,
TemplateEditorView, StartFromTemplateView, GuidedWorkoutView, SyncView

### Theme Module (7 files in Gymplicity/Theme/)

GymColors, GymTypography, GymMetrics, GymModifiers, MascotView,
AnimatedMascotView, GymProgressBar

- **Mascot "Lifty":** Bathroom-sign stick figure (Path strokes, round caps). 10 poses, 6 animations. 27 appearances across the app.
- **Palette:** iron/steel/chalk/rubber + energy orange, power green, focus blue
- **Typography:** SF Pro Rounded throughout, monospaced digits for numbers

### Sync Module (4 files in Gymplicity/Sync/)

SyncPayload, SyncEngine, SyncSessionManager, IdentityReconciliation

- **SyncPayload:** Codable DTOs mirroring all entities/joins + payload builder
- **SyncEngine:** Idempotent PUT merge (INSERT IF NOT EXISTS by UUID)
- **SyncSessionManager:** Multipeer Connectivity lifecycle (advertise/browse/connect/send)
- **IdentityReconciliation:** First-time pairing UUID rewrite (trainer's UUID wins)

## Conventions

- `is` prefix for Bool properties (isTrainer, isComplete, isCompleted)
- Entity postfix on all @Model classes (IdentityEntity, not Identity)
- Relationship traversal via extension methods on entities, not stored properties
- Cascade deletes down ownership chain; nullify for ExerciseSets
- Computed properties (volume, exerciseCount) derived from traversal, never stored

## Rules

- Never modify .xcodeproj / .pbxproj files directly
- New files must be added to the Xcode target manually
- All relationship queries take a ModelContext parameter
- Keep join tables as plain @Model classes with UUID pairs only
