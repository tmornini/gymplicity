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
                    TemplateEditorView(template: template, trainer: trainer)
                } label: {
                    TemplateRow(template: template)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.deleteWorkout(templates[index])
                }
                SyncTrigger.structureChanged()
            }

            if templates.isEmpty {
                Section {
                    VStack(spacing: GymMetrics.space16) {
                        AnimatedMascotView(
                            pose: .thinking,
                            animation: .pulse,
                            color: GymColors.secondaryText
                        )
                            .frame(height: GymMetrics.mascotMedium)
                        Text("Create your first workout template")
                            .font(GymFont.body)
                            .foregroundStyle(GymColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GymMetrics.space16)
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
        let template = WorkoutEntity(
            isTemplate: true,
            templateName: "New Template"
        )
        modelContext.insert(template)
        modelContext.insert(
            IdentityWorkouts(
                identityId: trainer.id,
                workoutId: template.id
            )
        )
        SyncTrigger.structureChanged()
    }
}

private struct TemplateRow: View {
    @Environment(\.modelContext) private var modelContext
    let template: WorkoutEntity

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(GymColors.focus)
                .frame(width: GymMetrics.setBarWidth)
                .padding(.trailing, GymMetrics.space8)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.templateName ?? "Untitled")
                    .font(GymFont.heading3)

                let groups = template.groups(in: modelContext)
                let setCount = groups
                    .flatMap { $0.sets(in: modelContext) }
                    .count
                let exerciseNames = exerciseNamesList()

                HStack(spacing: 8) {
                    Text(
                        "\(groups.count)"
                        + " group"
                        + "\(groups.count == 1 ? "" : "s")"
                    )
                    Text("\(setCount) set\(setCount == 1 ? "" : "s")")
                }
                .font(GymFont.caption)
                .foregroundStyle(GymColors.secondaryText)

                if !exerciseNames.isEmpty {
                    Text(exerciseNames)
                        .font(GymFont.caption)
                        .foregroundStyle(GymColors.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func exerciseNamesList() -> String {
        template.exerciseNames(in: modelContext)
    }
}
