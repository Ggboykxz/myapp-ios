import SwiftUI

/// Feuille de création d'un nouvel élément.
///
/// La feuille hérite de l'environnement de l'écran présentateur : le
/// ViewModel n'a donc pas à être transmis manuellement.
struct NewItemSheet: View {
    @Environment(ItemListViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titre") {
                    TextField("Ex. Rendez-vous dentiste", text: $title)
                }

                Section("Note") {
                    TextField(
                        "Détails (facultatif)",
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Nouvel élément")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        model.addItem(title: title, note: note)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NewItemSheet()
        .environment(ItemListViewModel())
}
