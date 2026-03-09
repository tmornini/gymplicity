# Gymplicity Manual Test Plan

Comprehensive manual testing guide for verifying all app functionality
via Xcode Simulator. Organized by feature area with clear steps and
expected results.

---

## Table of Contents

1. [Setup & Prerequisites](#1-setup--prerequisites)
2. [Identity & Onboarding](#2-identity--onboarding)
3. [Trainee Management](#3-trainee-management)
4. [Workout Lifecycle](#4-workout-lifecycle)
5. [Set Entry & Completion](#5-set-entry--completion)
6. [Guided Workout Mode](#6-guided-workout-mode)
7. [Templates](#7-templates)
8. [Exercise Search](#8-exercise-search)
9. [Multi-Trainee Workouts](#9-multi-trainee-workouts)
10. [Workout History & Progress Charts](#10-workout-history--progress-charts)
11. [Cascade Deletes](#11-cascade-deletes)
12. [Sync & Pairing](#12-sync--pairing)
13. [Theme & Visual](#13-theme--visual)
14. [Edge Cases & Boundaries](#14-edge-cases--boundaries)
15. [Integration Scenarios](#15-integration-scenarios)

---

## 1. Setup & Prerequisites

### Simulator Configuration

- **Required:** iOS 17+ Simulator (iPhone 15 or newer recommended)
- **Build:** `build/simulate` from project root
- **Reset state:** Erase simulator via Device > Erase All Content and
  Settings to start fresh between full test runs

### Before Each Test Section

Unless stated otherwise, start from a fresh simulator state with:
- One trainer identity created
- At least one trainee added

---

## 2. Identity & Onboarding

### 2.1 First Launch — Welcome Screen

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Launch app on fresh simulator | Welcome screen with animated Lifty mascot and "Get Started" button |
| 2 | Tap "Get Started" | Role selection alert appears: "I'm a Trainer" / "I'm a Trainee" |
| 3 | Tap Cancel on alert | Returns to welcome screen, no identity created |

### 2.2 Trainer Identity Creation

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap "Get Started" > "I'm a Trainer" | Name entry prompt appears |
| 2 | Enter "Coach Mike" and confirm | HomeView appears with trainer name visible |
| 3 | Kill and relaunch app | HomeView loads directly (no welcome screen) |

### 2.3 Trainee Identity Creation

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Fresh simulator, tap "Get Started" > "I'm a Trainee" | Name entry prompt appears |
| 2 | Enter name and confirm | ProfileView appears (trainee sees own profile, not HomeView) |

### 2.4 Default Name Fallback

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap "Get Started" > "I'm a Trainer" | Name prompt appears |
| 2 | Leave name empty and confirm | Identity created with default name "Trainer" |

---

## 3. Trainee Management

### 3.1 Add Trainee

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | From HomeView, tap "+" or "Add Trainee" | AddTraineeView sheet appears |
| 2 | Enter "Alice" | "Add" button becomes enabled |
| 3 | Tap "Add" | Sheet dismisses, "Alice" appears in trainees list |
| 4 | Verify sorting | Trainees sorted A-Z by name |

### 3.2 Add Trainee — Empty Name

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Open AddTraineeView | "Add" button is disabled |
| 2 | Enter spaces only | "Add" button remains disabled (name is trimmed) |

### 3.3 Trainee Row Status

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | View trainee with no active workout | Row shows "Start" pill |
| 2 | Start workout for trainee | Row changes to "In Workout" pill |
| 3 | End the workout | Row returns to "Start" pill |

### 3.4 Rename Trainee

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap trainee row to open ProfileView | Profile loads |
| 2 | Tap "Edit" (top-right) | Name edit alert appears |
| 3 | Change name to "Alice B." and confirm | Name updates in ProfileView and HomeView list |

### 3.5 Delete Trainee

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Swipe left on trainee row in HomeView | Delete action appears |
| 2 | Confirm deletion | Trainee removed from list; all workouts, groups, sets, and joins cascade deleted |

### 3.6 Empty Trainee List

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Delete all trainees | "Add your first trainee" prompt with button appears |

---

## 4. Workout Lifecycle

### 4.1 Start Blank Workout

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Swipe right on trainee row, tap "Start" | ActiveWorkoutView opens with empty workout |
| 2 | Verify toolbar | Trainee name and date shown; "End" (red) and delete (trash) buttons visible |

### 4.2 Start Workout — Already Active

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Start workout for trainee | Workout created |
| 2 | Return to HomeView | "Start" swipe action is NOT available for that trainee |

### 4.3 Add Standalone Exercise

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In active workout, tap "Add Exercise" | AddExerciseView sheet opens |
| 2 | Search and select "Bench Press" | New group created with one set; exercise name shown as section header |
| 3 | Verify initial set | Weight and reps pre-seeded from last session (or 0/0 if first time) |

### 4.4 Add Superset

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap "Add Superset" | AddExerciseView opens for first exercise |
| 2 | Select "Lat Pulldown" | Superset group created, header shows "Superset 1" |
| 3 | Tap "Add Set" in superset group | AddExerciseView opens (can pick different exercise) |
| 4 | Select "Dumbbell Row" | Second set added to same superset with different exercise |

### 4.5 Add Set to Standalone Group

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In a standalone group (e.g., Bench Press), tap "Add Set" | New set added automatically with same exercise (no picker) |
| 2 | Verify seeding | Weight/reps pre-filled from owner's last completed set for that exercise |

### 4.6 Delete Set

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Swipe left on a set row | Delete action appears |
| 2 | Confirm | Set removed; exercise still exists in catalog |

### 4.7 Remove Group

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap "Remove Group" (or "Remove Superset") | Confirmation dialog shows set count |
| 2 | Confirm | Group and all its sets cascade deleted |

### 4.8 End Workout

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap "End" (red button) | Confirmation dialog shows group and set counts |
| 2 | Confirm "End Workout" | Workout marked isCompleted=true; view dismisses; workout moves from Active Workouts to history |

### 4.9 Delete Workout

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap trash icon | Confirmation dialog with "This cannot be undone" warning |
| 2 | Confirm | Workout and all groups, sets, and joins cascade deleted; view dismisses |

---

## 5. Set Entry & Completion

### 5.1 Edit Weight and Reps

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap a set's weight/reps area | SetEntryView sheet opens with exercise name, Lifty mascot |
| 2 | Verify keyboard | Weight field focused, decimal pad keyboard |
| 3 | Enter "155.5" for weight, tap reps field | Reps field focused, number pad keyboard |
| 4 | Enter "8" for reps, tap "Done" | Sheet dismisses; set shows "155.5 x 8"; set marked completed |

### 5.2 Previous Set Reference

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Complete a set for Bench Press (e.g., 135 x 10) | Set saved |
| 2 | Add another set for same exercise | New set shows "Last time: 135 x 10" pill in SetEntryView |
| 3 | First-ever set for a new exercise | No "Last time" pill shown |

### 5.3 Toggle Completion via Checkmark

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap checkmark on an incomplete set | Checkmark fills; set gets strikethrough styling |
| 2 | Tap checkmark again | Completion toggled off; strikethrough removed |

### 5.4 Zero Values

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Open SetEntryView, leave both fields empty | Fields default to 0 |
| 2 | Tap "Done" | Set saved as 0 x 0; still marked completed |

### 5.5 Decimal Weight

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Enter "2.5" as weight | Saved correctly, displays as "2.5" (no trailing zeros) |

---

## 6. Guided Workout Mode

### 6.1 Enter Guided Mode

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In active workout with sets, tap Lifty button in bottom toolbar | GuidedWorkoutView opens |
| 2 | Verify display | Current exercise name (large), "Group X of Y - Set X of Z", weight/reps fields, "Done" button, progress bar |
| 3 | Verify starting position | First incomplete set selected |

### 6.2 Complete Set and Advance

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Enter weight and reps | Fields populated |
| 2 | Tap "Done" | Set marked complete; Lifty walking transition animation plays; advances to next incomplete set |
| 3 | Verify progress bar | Updates percentage (e.g., "3/10 sets - 30%") |

### 6.3 Complete All Sets

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Complete the final set | Celebration view: Lifty celebrating, "All Sets Complete!", set count, "End Workout" button |
| 2 | Tap "End Workout" | Workout marked complete, view dismisses |

### 6.4 Resume at Correct Position

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Complete 3 of 8 sets in guided mode | Progress at 3/8 |
| 2 | Switch to list view (tap "List View") | ActiveWorkoutView shows; 3 sets have checkmarks |
| 3 | Re-enter guided mode | Resumes at set 4 (first incomplete) |

### 6.5 Mixed Completion (List + Guided)

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In list view, mark set 5 complete via checkmark | Set 5 completed |
| 2 | Enter guided mode | Starts at set 4 (first incomplete), skipping already-completed set 5 later |

### 6.6 Empty Workout in Guided Mode

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Create blank workout, enter guided mode | "No Sets" empty state message |
| 2 | Switch to list view, add exercises | Sets created |
| 3 | Re-enter guided mode | Sets now visible, first set focused |

### 6.7 Toolbar Actions

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap "List View" | Returns to ActiveWorkoutView |
| 2 | Tap "End Workout" | Same confirmation dialog as list mode |
| 3 | Tap trash (Delete) | Same delete confirmation as list mode |

---

## 7. Templates

### 7.1 Create Template

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | From HomeView, tap Templates section | TemplateListView opens |
| 2 | Tap "+" | New template created with name "New Template" |
| 3 | Verify template row | Shows name, "0 sets", no exercise names |

### 7.2 Edit Template Structure

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap template row | TemplateEditorView opens |
| 2 | Tap "Add Exercise" | AddExerciseView opens |
| 3 | Select "Squat" | Group created with one set |
| 4 | Tap set row | TemplateSetEntryView opens (targets only, no completion toggle) |
| 5 | Enter "225" weight, "5" reps, save | Set shows "225 x 5" with target icon (not checkmark) |

### 7.3 Rename Template

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In TemplateEditorView, tap "Rename" | Alert with text field |
| 2 | Enter "Leg Day" and confirm | Template name updates in editor and list |

### 7.4 Delete Template

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In TemplateListView, swipe left on template | Delete action appears |
| 2 | Confirm | Template removed from list |

### 7.5 Instantiate Template

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | From ProfileView (trainee with no active workout), tap "Start from Template" | StartFromTemplateView sheet opens with Lifty mascot |
| 2 | Verify list | Shows all trainer's templates with exercise/set counts |
| 3 | Tap a template (e.g., "Leg Day") | New workout created; navigates to ActiveWorkoutView |
| 4 | Verify cloned structure | All groups, sets, and exercises copied from template; all sets incomplete; new UUIDs |

### 7.6 Template Independence (Deep Copy)

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Instantiate "Leg Day" for trainee | Workout created |
| 2 | Modify a set's weight in the workout | Weight changed in workout |
| 3 | Open TemplateEditorView for "Leg Day" | Original template weights unchanged |
| 4 | Instantiate "Leg Day" again for same trainee (after ending first workout) | Second independent workout created with original template values |

### 7.7 Template — Empty State

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Delete all templates | TemplateListView shows "Create your first template" prompt |
| 2 | From ProfileView, check "Start from Template" | Button hidden (no templates available) |

### 7.8 Start from Template — Swipe Action

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | From HomeView, swipe right on trainee row | "Template" action appears (only if no active workout AND templates exist) |
| 2 | Tap "Template" | StartFromTemplateView opens |

---

## 8. Exercise Search

### 8.1 Empty Search — User Exercises

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Open AddExerciseView with empty search field | "Your Exercises" section shows all trainer's exercises, recently used first |
| 2 | No catalog results shown | Catalog section hidden when search is empty |

### 8.2 Name Search

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Type "bench" | Results include "Bench Press", "Incline Bench Press", and other bench variations |
| 2 | Verify sections | "Your Exercises" (if any match) and "Exercise Catalog" sections |
| 3 | Verify catalog match pills | Color-coded pills showing match reason (e.g., orange for exact name) |

### 8.3 Negation Search

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Type "bench -machine" | Results include bench variations but exclude any with "machine" in name |
| 2 | Type "-dumbbell" | All exercises except those containing "dumbbell" |
| 3 | Type "shoulder -dumbbell -barbell" | Only shoulder exercises that are neither dumbbell nor barbell |

### 8.4 Alias Matching

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Type "db rows" | Finds "Dumbbell Row" via alias matching |
| 2 | Verify match pill | Shows alias match reason (blue pill) |

### 8.5 Muscle Group Search

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Type "chest" | Results include exercises with chest as primary or secondary muscle |
| 2 | Verify match pills | Green pill for primaryMuscle, chalk for secondaryMuscle |

### 8.6 Fuzzy Matching

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Type "benchh" (typo) | Still finds "Bench Press" via Levenshtein distance |
| 2 | Type "squatt" | Still finds "Squat" |

### 8.7 Create Custom Exercise

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Type "My Special Move" in search | No exact match found |
| 2 | Tap "Add" button | Custom exercise created, linked to trainer via TrainerExercises, set created |
| 3 | Next time searching | "My Special Move" appears in "Your Exercises" |

### 8.8 Select Catalog Exercise

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Search and tap a catalog exercise | Exercise added to trainer's collection, set created with that exercise |
| 2 | Next search | Exercise now appears in "Your Exercises" section |

### 8.9 Search Result Ranking

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Search a term with multiple match types | Exact name matches ranked first, then aliases, then muscles, then joints, then body regions |
| 2 | Ties | Broken alphabetically |

---

## 9. Multi-Trainee Workouts

### 9.1 Container Navigation

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Start workouts for trainees A, B, and C | All three appear in Active Workouts on HomeView |
| 2 | Tap A's active workout row | ActiveWorkoutsContainerView opens showing A's workout |
| 3 | Verify page dots | Three dots shown; first highlighted |

### 9.2 Swipe Between Trainees

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Swipe left (>50pt) | Transitions to trainee B's workout; page dot updates |
| 2 | Swipe left again | Transitions to trainee C |
| 3 | Swipe right | Back to trainee B |

### 9.3 Independent View Modes

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | On trainee A's workout, enter guided mode | Guided view shown |
| 2 | Swipe to trainee B | B shows in list mode (independent) |
| 3 | Swipe back to A | A still in guided mode (mode persists per trainee) |

### 9.4 Toolbar Updates

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Navigate between trainees | Toolbar name updates to current trainee |
| 2 | Single active workout | Date shown instead of page dots |

---

## 10. Workout History & Progress Charts

### 10.1 Recent Workouts List

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Complete 2+ workouts for a trainee | Workouts appear in ProfileView "Recent Workouts" section |
| 2 | Verify row content | Date, exercise count, total volume (e.g., "Total volume: 5280 lb"), exercise names |
| 3 | Verify ordering | Newest first |
| 4 | Verify limit | Maximum 20 shown |

### 10.2 Workout History Detail

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap a completed workout row | WorkoutHistoryView opens (read-only) |
| 2 | Verify summary | Date, exercise count, set count, total volume |
| 3 | Verify groups | Each group lists sets with exercise name, weight x reps, volume, completion status |
| 4 | Verify supersets | Labeled "Superset X" with mixed exercises |

### 10.3 Delete from History

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In WorkoutHistoryView, tap trash icon | Confirmation dialog |
| 2 | Confirm | Workout deleted; returns to ProfileView; workout gone from history |

### 10.4 Progress by Exercise

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In ProfileView, scroll to "Progress by Exercise" | Lists all exercises used, sorted A-Z |
| 2 | Each row shows | Exercise name and last set performed (weight x reps) |
| 3 | Tap an exercise | ProgressChartsView opens |

### 10.5 Weight @ Reps Over Time Chart

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Complete 3+ workouts with same exercise at different rep counts | Chart data accumulates |
| 2 | Open ProgressChartsView | Line chart with date on X-axis, weight on Y-axis |
| 3 | Verify lines | One line per rep count (e.g., "5-rep", "8-rep", "10-rep") with different colors |
| 4 | Verify data | Shows best weight for each rep count per workout |

### 10.6 Total Volume Over Time Chart

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Same setup as 10.5 | Multiple workouts with volume data |
| 2 | Verify area chart | Date on X-axis, volume on Y-axis; area fill with line overlay |
| 3 | Verify calculation | Volume = sum of (weight x reps) for all sets of that exercise per workout |

### 10.7 Charts — Empty State

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Open ProgressChartsView for exercise with no completed sets | Deadlifting Lifty mascot with "Complete workouts to track your progress" |

### 10.8 Empty Workout History

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | View ProfileView for trainee with no completed workouts | "Let's get your first workout in!" prompt |

---

## 11. Cascade Deletes

### 11.1 Delete Trainee — Full Cascade

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Create trainee with 2 completed workouts (each with groups and sets) | Data exists |
| 2 | Delete trainee from HomeView swipe | Trainee removed |
| 3 | Verify | All workouts, groups, sets gone; TrainerTrainees, IdentityWorkouts, WorkoutGroups, GroupSets joins removed |

### 11.2 Delete Workout — Cascade

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Create workout with 3 groups and 10 sets | Workout populated |
| 2 | Delete workout (trash icon) | Workout removed |
| 3 | Verify | All groups, sets deleted; IdentityWorkouts, WorkoutGroups, GroupSets joins removed; TemplateInstances join removed if from template |

### 11.3 Delete Group — Cascade

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Create group with 4 sets | Group populated |
| 2 | Tap "Remove Group" and confirm | Group and all 4 sets deleted; WorkoutGroups, GroupSets joins removed |

### 11.4 Delete Set — Nullify Exercise Link

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Delete a single set via swipe | Set removed |
| 2 | Verify exercise | Exercise still exists in trainer's catalog (ExerciseSets join removed, exercise preserved) |

### 11.5 Delete Exercise — Orphaned Sets

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Delete an exercise that was used in completed workouts | Exercise removed |
| 2 | View completed workout containing that exercise | Set still visible but exercise name shows generic "Exercise" |

### 11.6 Cross-Trainee Isolation

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Create trainees A and B, each with workouts | Both have data |
| 2 | Delete trainee A | A's data gone |
| 3 | Verify trainee B | B's workouts, groups, sets all intact |

---

## 12. Sync & Pairing

> **Note:** Sync testing requires two devices/simulators. Some steps
> may be limited to verification of UI states on a single simulator.

### 12.1 Open Sync View

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Trainer: tap sync icon (top-left) in HomeView | SyncView sheet opens |
| 2 | Trainee: tap sync icon (top-left) in ProfileView | SyncView sheet opens |
| 3 | Verify initial state | "idle" state with prompt to start searching |

### 12.2 Discovery State

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Tap to start searching | State changes to "searching"; animated Lifty mascot |
| 2 | "Nearby Devices" section appears | Lists discovered peers with name and role |
| 3 | Already-paired peer | Shows green "Paired" badge |
| 4 | New peer | Shows blue "New" badge |

### 12.3 First-Time Pairing Flow (Two Devices)

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Both devices open SyncView and start searching | Each discovers the other |
| 2 | Tap discovered peer on one device | Connection initiated; state → "connecting" |
| 3 | Other device receives pairing offer | Pairing view shows sender info |
| 4 | If linked identity provided | Verification: "X wants to pair with you as 'Y'. Is this you?" |
| 5 | Accept pairing | Match-or-new screen: select existing identity or "New" |
| 6 | Select identity and confirm | PairedDevices row created; state → "syncing" |
| 7 | Sync completes | State → "connected"; merge result shown (e.g., "Synced 3 workouts, 15 sets") |

### 12.4 Identity Reconciliation

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Trainer (Device A) has trainee "Alice" (UUID-A) | Pre-existing trainee |
| 2 | Alice's device (Device B) has her own identity (UUID-B) | Different UUID |
| 3 | Pair devices; trainer links Device B to existing "Alice" | IdentityAliases created: (UUID-A, UUID-B) |
| 4 | Verify on trainer device | Workouts from both UUIDs visible under single "Alice" profile |

### 12.5 Connected State

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | After successful pairing/sync | "Connected to X" message; last sync summary; "Background sync active" note |
| 2 | Tap "Sync Now" | Triggers immediate sync; updates merge result |

### 12.6 Sync — Error State

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Simulate disconnection during sync | Error state with message |
| 2 | Tap "Try Again" | Reattempts connection |

### 12.7 Payload Merge — Role Authority

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Trainer modifies exercise name | After sync, trainee receives updated name (trainer has authority) |
| 2 | Trainee completes sets | After sync, trainer sees trainee's completed data |
| 3 | Both modify same set | Trainer's version wins (trainer authority) |

---

## 13. Theme & Visual

### 13.1 Lifty Mascot Appearances

| Location | Expected Pose | Animation |
|----------|--------------|-----------|
| Welcome screen | waving | bounce |
| Searching (Sync) | walking | pulse |
| Set entry sheet | lifting | none (static) |
| Guided mode progress | lifting | rep |
| Workout completion | celebrating | bounce |
| Empty charts | deadlifting | none |
| Start from Template | lifting | bounce |
| No search results | thinking | wobble |

### 13.2 Color Verification

| Element | Expected Color |
|---------|---------------|
| Active workout indicator dot | Green (activeIndicator) |
| "End" button | Red (danger) |
| Set completion checkmark | Green (power) |
| Exercise search match pills | Orange (exact), Blue (alias), Green (muscle) |
| Progress bar | Blue (focus) |
| Template accent bar | Blue (focus) |
| Trainee avatar | Iron/steel tones |

### 13.3 Typography

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Check weight/reps displays throughout app | Monospaced digits (SF Pro Rounded, monospaced digit) |
| 2 | Check headings | SF Pro Rounded at appropriate sizes |
| 3 | Verify numeric alignment | Numbers align properly in columns (monospaced) |

### 13.4 GymProgressBar

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | In guided mode, progress bar at 0% | Empty bar |
| 2 | Complete sets progressively | Bar fills proportionally with focus blue color |
| 3 | 100% completion | Full bar |

### 13.5 Set Completion Styling

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Mark set complete | Row gets strikethrough styling via .setCompletion modifier |
| 2 | Unmark set | Strikethrough removed |

### 13.6 Status Pills

| Element | Expected Style |
|---------|---------------|
| "In Workout" | gymPill modifier, active color |
| "Start" | gymPill modifier, neutral color |
| "Paired" (sync) | gymPill modifier, green |
| "New" (sync) | gymPill modifier, blue |

---

## 14. Edge Cases & Boundaries

### 14.1 Empty States

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | HomeView with no trainees | Prompt to add first trainee |
| 2 | ProfileView with no workouts | "Let's get your first workout in!" |
| 3 | TemplateListView with no templates | Prompt to create first template |
| 4 | ProgressChartsView with no data | Deadlifting mascot empty state |
| 5 | Active workout with no groups | "Add Exercise" and "Add Superset" buttons visible |

### 14.2 Numeric Boundaries

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Enter 0 weight, 0 reps | Saved as 0 x 0, no crash |
| 2 | Enter very large weight (e.g., 999.99) | Parsed and displayed correctly |
| 3 | Enter decimal reps (e.g., "8.5") | Truncated to integer (8) |
| 4 | Enter negative values | Converted to 0 or handled gracefully |

### 14.3 Text Input Boundaries

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Very long trainee name (50+ chars) | Truncated in display, saved fully |
| 2 | Special characters in name (e.g., "O'Brien", "Muller") | Handled correctly |
| 3 | Whitespace-only name | Treated as empty, not accepted |
| 4 | Unicode/emoji in name | Saved and displayed correctly |

### 14.4 App Lifecycle

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Start workout, force-quit app, relaunch | Workout still exists with all progress |
| 2 | Guided mode mid-set, background app, return | View intact, resumes where left off |
| 3 | Edit set, receive phone call, return | Changes preserved |

### 14.5 Rapid Interactions

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Rapidly tap "Add Set" multiple times | Creates correct number of sets, no duplicates or crashes |
| 2 | Rapidly toggle set completion | Toggles correctly without visual glitches |
| 3 | Rapid swipe between trainees in container | Smooth transitions, correct trainee shown |

---

## 15. Integration Scenarios

### 15.1 Full Workout Cycle

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Add trainee "Alice" | Appears in list |
| 2 | Start blank workout for Alice | ActiveWorkoutView opens |
| 3 | Add "Bench Press" from catalog | Group created with seeded set |
| 4 | Add 2 more sets to Bench Press group | 3 total sets, all same exercise |
| 5 | Complete all 3 sets with values (135x10, 155x8, 175x6) | All marked complete with strikethrough |
| 6 | Add "Squat" exercise | Second group created |
| 7 | Complete 2 squat sets (225x5, 245x3) | Both marked complete |
| 8 | End workout | Workout marked complete, view dismisses |
| 9 | Open Alice's ProfileView | Workout appears in Recent Workouts with "2 exercises", volume shown |
| 10 | Tap workout | WorkoutHistoryView shows all groups, sets, volumes |
| 11 | Tap "Bench Press" in Progress by Exercise | ProgressChartsView shows data point(s) |

### 15.2 Template Workflow

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Create template "Push Day" | Template in list |
| 2 | Add Bench Press: 3 sets (135x10, 155x8, 175x5) | Sets with target weights |
| 3 | Add Superset: Overhead Press (95x8) + Lateral Raise (20x12) | Superset with 2 exercises |
| 4 | Instantiate for trainee Alice | New workout with all exercises/sets cloned |
| 5 | Modify set 1 weight to 145 in workout | Workout updated |
| 6 | Verify template unchanged | Template still shows 135 for set 1 |
| 7 | End workout | Moves to history |
| 8 | Instantiate same template again (for new workout) | Fresh copy with original 135 value |

### 15.3 Multi-Trainee Session

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Add trainees A, B, C | All in list |
| 2 | Start workouts for all three | All appear in Active Workouts section |
| 3 | Tap A's workout | Container opens with 3 page dots |
| 4 | Add exercises and sets for A | Data saved |
| 5 | Swipe to B, add different exercises | B's workout independent |
| 6 | Switch B to guided mode | Guided view for B |
| 7 | Swipe to A | List mode preserved for A |
| 8 | Swipe to C | List mode (default) for C |
| 9 | End B's workout (from guided mode) | B removed from container |
| 10 | Verify page dots | Now 2 dots (A and C) |

### 15.4 Negation Search Workflow

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Add exercises: Bench Press, Incline Bench, Machine Bench, DB Bench | All in catalog |
| 2 | Search "bench -machine" | Shows Bench Press, Incline Bench, DB Bench (Machine excluded) |
| 3 | Search "bench -machine -incline" | Shows Bench Press, DB Bench |
| 4 | Search "-bench" | Shows all exercises except those containing "bench" |

### 15.5 Cascade Delete Verification

| # | Step | Expected Result |
|---|------|-----------------|
| 1 | Create trainee with 3 workouts (5 groups, 15 sets total) | All data created |
| 2 | Create second trainee with 2 workouts | Independent data |
| 3 | Delete first trainee | First trainee's workouts, groups, sets, all joins removed |
| 4 | Second trainee | All data intact, unaffected |

---

## Final Verification Checklist

- [ ] Identity creation (trainer and trainee roles)
- [ ] Add, rename, delete trainees
- [ ] Start workout (blank and from template)
- [ ] Add exercises (user catalog, exercise catalog, custom creation)
- [ ] Add and delete sets and groups (standalone and superset)
- [ ] Set entry with weight/reps via SetEntryView
- [ ] Toggle set completion via checkmark
- [ ] Previous set reference displays correctly
- [ ] Guided mode: navigation, completion, progress bar, celebration
- [ ] End workout with confirmation
- [ ] Delete workout with cascade
- [ ] Profile: recent workouts, progress by exercise
- [ ] Workout history detail (read-only)
- [ ] Progress charts: weight/reps and volume over time
- [ ] Create, edit, rename, delete templates
- [ ] Template instantiation with deep copy
- [ ] Exercise search: name, alias, muscle, fuzzy, negation
- [ ] Multi-trainee container: swiping, independent modes
- [ ] Cascade deletes at every level (trainee, workout, group, set)
- [ ] Sync: discovery, pairing, merge, connected state
- [ ] Identity reconciliation (alias linking)
- [ ] Lifty mascot poses and animations
- [ ] Theme colors, typography, monospaced digits
- [ ] Empty states for all views
- [ ] App persistence across force-quit
- [ ] No orphaned data after deletes
