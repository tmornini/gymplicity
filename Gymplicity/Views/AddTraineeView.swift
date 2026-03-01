import SwiftUI
import SwiftData

struct AddTraineeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let trainer: IdentityEntity
    @State private var name = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { save() }
            }
            .navigationTitle("New Trainee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFieldFocused = true }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let trainee = IdentityEntity(name: trimmed, isTrainer: false)
        modelContext.insert(trainee)
        let join = TrainerTrainees(trainerId: trainer.id, traineeId: trainee.id)
        modelContext.insert(join)
        dismiss()
    }
}
