import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: WorkoutEntity
    @State private var showingAddExercise = false
    @State private var targetGroup: WorkoutGroupEntity?
    @State private var editingName = false
    @State private var nameText = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Text(template.templateName ?? "Untitled")
                        .font(GymFont.heading3)
                    Spacer()
                    Button("Rename") {
                        nameText = template.templateName ?? ""
                        editingName = true
                    }
                    .font(GymFont.label)
                    .foregroundStyle(GymColors.energy)
                }
            }

            ForEach(template.sortedGroups(in: modelContext)) { group in
                Section {
                    ForEach(group.sortedSets(in: modelContext)) { set in
                        TemplateSetRow(set: set, group: group, template: template)
                    }
                    .onDelete { offsets in deleteSets(from: group, at: offsets) }

                    Button {
                        targetGroup = group
                        showingAddExercise = true
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .font(GymFont.label)
                            .foregroundStyle(GymColors.energy)
                    }
                } header: {
                    Text("Superset \(group.order + 1)")
                        .font(GymFont.heading3)
                        .textCase(nil)
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
                Text(template.templateName ?? "Template")
                    .font(GymFont.heading3)
            }
        }
        .alert("Rename Template", isPresented: $editingName) {
            TextField("Template Name", text: $nameText)
            Button("Save") {
                let trimmed = nameText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { template.templateName = trimmed }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingAddExercise) {
            if let group = targetGroup {
                AddExerciseView(group: group)
            }
        }
    }

    private func addGroup() {
        let group = WorkoutGroupEntity(order: template.nextGroupOrder(in: modelContext))
        modelContext.insert(group)
        modelContext.insert(WorkoutGroups(workoutId: template.id, groupId: group.id))
        targetGroup = group
        showingAddExercise = true
    }

    private func deleteSets(from group: WorkoutGroupEntity, at offsets: IndexSet) {
        let sorted = group.sortedSets(in: modelContext)
        for index in offsets {
            modelContext.deleteSet(sorted[index])
        }
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
                Text(exercise?.name ?? "Exercise")
                    .font(GymFont.label)
                    .foregroundStyle(GymColors.secondaryText)
                    .frame(minWidth: 60, alignment: .leading)

                if set.weight > 0 || set.reps > 0 {
                    Text(formatWeight(set.weight))
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
            TemplateSetEntryView(set: set, exercise: set.exercise(in: modelContext))
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) lb"
        }
        return String(format: "%.1f lb", weight)
    }
}

// MARK: - Template Set Entry (saves weight/reps without marking complete)

private struct TemplateSetEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var set: SetEntity
    let exercise: ExerciseEntity?

    @State private var weightText = ""
    @State private var repsText = ""
    @FocusState private var focusedField: Field?

    enum Field { case weight, reps }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(exercise?.name ?? "Exercise")
                    .font(GymFont.heading2)

                Text("Target")
                    .font(GymFont.label)
                    .foregroundStyle(GymColors.secondaryText)

                HStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Weight")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(GymFont.numericEntrySmall)
                            .textFieldStyle(.plain)
                            .frame(width: 120)
                            .focused($focusedField, equals: .weight)
                        Rectangle()
                            .fill(GymColors.focus)
                            .frame(width: 120, height: 2)
                        Text("lb")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                    }

                    Text("x")
                        .font(GymFont.heading2)
                        .foregroundStyle(GymColors.secondaryText)

                    VStack(spacing: 8) {
                        Text("Reps")
                            .font(GymFont.caption)
                            .foregroundStyle(GymColors.secondaryText)
                        TextField("0", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(GymFont.numericEntrySmall)
                            .textFieldStyle(.plain)
                            .frame(width: 120)
                            .focused($focusedField, equals: .reps)
                        Rectangle()
                            .fill(GymColors.focus)
                            .frame(width: 120, height: 2)
                        Text(" ")
                            .font(GymFont.caption)
                    }
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(GymColors.energy)
                }
            }
            .onAppear {
                weightText = set.weight > 0 ? formatWeightValue(set.weight) : ""
                repsText = set.reps > 0 ? "\(set.reps)" : ""
                focusedField = .weight
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        set.weight = Double(weightText) ?? 0
        set.reps = Int(repsText) ?? 0
        dismiss()
    }

    private func formatWeightValue(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
