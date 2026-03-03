import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    let trainer: IdentityEntity

    var body: some View {
        let templates = trainer.templates(in: modelContext)
        List {
            ForEach(templates) { template in
                NavigationLink {
                    TemplateEditorView(template: template)
                } label: {
                    TemplateRow(template: template)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.deleteWorkout(templates[index])
                }
            }

            if templates.isEmpty {
                ContentUnavailableView {
                    Label("No Templates", systemImage: "doc.text")
                } description: {
                    Text("Create a reusable workout plan")
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createTemplate()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func createTemplate() {
        let template = WorkoutEntity(isTemplate: true, templateName: "New Template")
        modelContext.insert(template)
        modelContext.insert(IdentityWorkouts(identityId: trainer.id, workoutId: template.id))
    }
}

private struct TemplateRow: View {
    @Environment(\.modelContext) private var modelContext
    let template: WorkoutEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.templateName ?? "Untitled")
                .font(.headline)

            let groups = template.groups(in: modelContext)
            let setCount = groups.flatMap { $0.sets(in: modelContext) }.count
            let exerciseNames = exerciseNamesList()

            HStack(spacing: 8) {
                Text("\(groups.count) group\(groups.count == 1 ? "" : "s")")
                Text("\(setCount) set\(setCount == 1 ? "" : "s")")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !exerciseNames.isEmpty {
                Text(exerciseNames)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func exerciseNamesList() -> String {
        let allSets = template.sortedGroups(in: modelContext).flatMap { $0.sortedSets(in: modelContext) }
        var seen = Swift.Set<UUID>()
        var names: [String] = []
        for set in allSets {
            if let exercise = set.exercise(in: modelContext), seen.insert(exercise.id).inserted {
                names.append(exercise.name)
            }
        }
        return names.joined(separator: ", ")
    }
}
