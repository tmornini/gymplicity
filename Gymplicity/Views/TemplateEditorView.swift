import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: WorkoutEntity
    let trainer: IdentityEntity
    @State private var showingAddExercise = false
    @State private var targetGroup: WorkoutGroupEntity?
    @State private var groupToDelete: WorkoutGroupEntity?
    @State private var editingName = false
    @State private var nameText = ""

    var body: some View {
        List {
            Section {
                HStack {
                    if let name = template.templateName(in: modelContext) {
                        Text(name)
                            .font(GymFont.heading3)
                    }
                    Spacer()
                    Button("Rename") {
                        nameText = template
                            .templateName(
                                in: modelContext
                            ) ?? ""
                        editingName = true
                    }
                    .font(GymFont.label)
                    .foregroundStyle(GymColors.energy)
                }
            }

            ForEach(template.sortedGroups(in: modelContext)) { group in
                Section {
                    ForEach(group.sortedSets(in: modelContext)) { set in
                        TemplateSetRow(
                            set: set,
                            group: group,
                            template: template
                        )
                    }
                    .onDelete { offsets in
                        deleteSets(
                            from: group,
                            at: offsets
                        )
                    }

                    Button {
                        targetGroup = group
                        showingAddExercise = true
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .font(GymFont.label)
                            .foregroundStyle(GymColors.energy)
                    }

                    Button(role: .destructive) {
                        groupToDelete = group
                    } label: {
                        Label(
                            group.isSuperset
                                ? "Remove Superset"
                                : "Remove Group",
                            systemImage: "trash"
                        )
                            .font(GymFont.label)
                    }
                } header: {
                    if group.isSuperset {
                        Text("Superset \(group.order + 1)")
                            .font(GymFont.heading3)
                            .textCase(nil)
                    } else if let name = group.exerciseName(
                        in: modelContext
                    ) {
                        Text(name)
                            .font(GymFont.heading3)
                            .textCase(nil)
                    }
                }
            }

            Section {
                Button {
                    addGroup()
                } label: {
                    Label("Add Superset", systemImage: "plus.circle.fill")
                        .font(GymFont.bodyStrong)
                        .foregroundStyle(GymColors.energy)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let name = template.templateName(
                    in: modelContext
                ) {
                    Text(name)
                        .font(GymFont.heading3)
                }
            }
        }
        .confirmationDialog(
            groupToDelete?.isSuperset == true
                ? "Remove Superset?"
                : "Remove Group?",
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            ),
            presenting: groupToDelete
        ) { group in
            Button("Remove", role: .destructive) {
                modelContext.deleteGroup(group)
                SyncTrigger.structureChanged()
                groupToDelete = nil
            }
            Button("Cancel", role: .cancel) { groupToDelete = nil }
        } message: { group in
            let count = group.sets(in: modelContext).count
            let kind = group.isSuperset
                ? "superset" : "group"
            let suffix = count == 1 ? "" : "s"
            Text(
                "This \(kind) has \(count)"
                + " set\(suffix)"
                + " that will be deleted."
            )
        }
        .alert("Rename Template", isPresented: $editingName) {
            TextField("Template Name", text: $nameText)
            Button("Save") {
                let trimmed = nameText
                    .trimmingCharacters(
                        in: .whitespaces
                    )
                if !trimmed.isEmpty {
                    let wId = template.id
                    let existing =
                        modelContext.fetchFirst(
                            FetchDescriptor<
                                WorkoutTemplate
                            >(
                                predicate: #Predicate {
                                    $0.workoutId
                                        == wId
                                }
                            )
                        )
                    if let existing {
                        existing.name = trimmed
                    } else {
                        modelContext.insert(
                            WorkoutTemplate(
                                workoutId: wId,
                                name: trimmed
                            )
                        )
                    }
                    SyncTrigger.entityUpdated(
                        .workout,
                        id: template.id
                    )
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingAddExercise) {
            if let group = targetGroup {
                AddExerciseView(group: group, trainer: trainer)
            }
        }
    }

    private func addGroup() {
        let group = WorkoutGroupEntity(
            order: template
                .nextGroupOrder(in: modelContext),
            isSuperset: false
        )
        modelContext.insert(group)
        modelContext.insert(
            WorkoutGroups(
                workoutId: template.id,
                groupId: group.id
            )
        )
        targetGroup = group
        showingAddExercise = true
        SyncTrigger.structureChanged()
    }

    private func deleteSets(
        from group: WorkoutGroupEntity,
        at offsets: IndexSet
    ) {
        modelContext.deleteSets(from: group, at: offsets)
        SyncTrigger.structureChanged()
    }
}

// MARK: - Template Set Row (no completion checkmark)

private struct TemplateSetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var set: SetEntity
    let group: WorkoutGroupEntity
    let template: WorkoutEntity
    @State private var showingEditor = false

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            HStack {
                let exercise = set.exercise(in: modelContext)
                VStack(alignment: .leading, spacing: GymMetrics.space4) {
                    if let name = exercise?.name {
                        Text(name)
                            .font(GymFont.label)
                            .foregroundStyle(GymColors.secondaryText)
                    }
                    ExerciseAttributePills(exercise: exercise)
                }
                .frame(
                    minWidth: GymMetrics
                        .minExerciseNameWidth,
                    alignment: .leading
                )

                if set.weight > 0 || set.reps > 0 {
                    Text(Weight.formatted(set.weight))
                        .font(GymFont.bodyMono)
                    Text("x")
                        .font(GymFont.caption)
                        .foregroundStyle(GymColors.secondaryText)
                    Text("\(set.reps)")
                        .font(GymFont.bodyMono)
                } else {
                    Text("Tap to set targets")
                        .font(GymFont.body)
                        .foregroundStyle(GymColors.tertiaryText)
                }

                Spacer()

                Image(systemName: "target")
                    .font(GymFont.caption)
                    .foregroundStyle(GymColors.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditor) {
            TemplateSetEntryView(
                set: set,
                exercise: set.exercise(
                    in: modelContext
                )
            )
        }
    }
}

// MARK: - Template Set Entry (saves weight/reps without marking complete)

private struct TemplateSetEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var set: SetEntity
    let exercise: ExerciseEntity?

    @State private var weightText = ""
    @State private var repsText = ""
    @FocusState private var focusedField: WeightRepsField.Field?

    var body: some View {
        NavigationStack {
            VStack(spacing: GymMetrics.space24) {
                VStack(spacing: GymMetrics.space4) {
                    if let name = exercise?.name {
                        Text(name)
                            .font(GymFont.heading2)
                    }
                    ExerciseAttributePills(exercise: exercise)
                }

                Text("Target")
                    .font(GymFont.label)
                    .foregroundStyle(GymColors.secondaryText)

                WeightRepsField(
                    weightText: $weightText,
                    repsText: $repsText,
                    font: GymFont.numericEntrySmall,
                    accentColor: GymColors.focus,
                    fieldWidth: GymMetrics
                        .fieldWidthCompact,
                    showLabels: true,
                    repsUnit: " ",
                    focusedField: $focusedField
                )

                Spacer()
            }
            .padding(.top, GymMetrics.space24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(GymColors.energy)
                        .disabled(!isInputValid)
                }
            }
            .onAppear {
                weightText = set.weight > 0
                    ? Weight.rawValue(set.weight)
                    : ""
                repsText = set.reps > 0
                    ? "\(set.reps)" : ""
                focusedField = .weight
            }
        }
        .presentationDetents([.medium])
    }

    private var isInputValid: Bool {
        (weightText.isEmpty
            || Double(weightText) != nil)
            && (repsText.isEmpty
                || Int(repsText) != nil)
    }

    private func save() {
        guard isInputValid else { return }
        set.weight = weightText.isEmpty
            ? 0 : Double(weightText)!
        set.reps = repsText.isEmpty
            ? 0 : Int(repsText)!
        SyncTrigger.entityUpdated(.set, id: set.id)
        dismiss()
    }
}
