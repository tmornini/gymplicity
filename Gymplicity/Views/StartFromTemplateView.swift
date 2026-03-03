import SwiftUI
import SwiftData

struct StartFromTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let trainer: IdentityEntity
    let trainee: IdentityEntity
    var onStart: (WorkoutEntity) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            let templates = trainer.templates(in: modelContext)
            List {
                ForEach(templates) { template in
                    Button {
                        guard trainee.activeWorkouts(in: modelContext).isEmpty else { return }
                        let workout = modelContext.instantiateTemplate(template, for: trainee)
                        onStart(workout)
                        dismiss()
                    } label: {
                        StartTemplateRow(template: template)
                    }
                }

                if templates.isEmpty {
                    ContentUnavailableView {
                        Label("No Templates", systemImage: "doc.text")
                    } description: {
                        Text("Create templates from the Templates screen first")
                    }
                }
            }
            .navigationTitle("Start from Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct StartTemplateRow: View {
    @Environment(\.modelContext) private var modelContext
    let template: WorkoutEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.templateName ?? "Untitled")
                .font(.headline)
                .foregroundStyle(.primary)

            let groups = template.groups(in: modelContext)
            let setCount = groups.flatMap { $0.sets(in: modelContext) }.count
            let exerciseCount = template.exerciseCount(in: modelContext)

            HStack(spacing: 8) {
                Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                Text("\(setCount) set\(setCount == 1 ? "" : "s")")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
