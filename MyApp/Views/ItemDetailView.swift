import SwiftUI

/// Détail d'un élément : lecture seule + bascule « terminé ».
///
/// L'écran relit l'élément depuis le ViewModel (`currentItem`) afin de
/// refléter l'état mis à jour par une suppression ou une autre mutation.
struct ItemDetailView: View {
    @Environment(ItemListViewModel.self) private var model

    let item: Item

    private var currentItem: Item? {
        model.items.first { $0.id == item.id }
    }

    var body: some View {
        let displayed = currentItem ?? item

        Form {
            Section("Titre") {
                Text(displayed.title)
            }

            Section("Note") {
                if displayed.note.isEmpty {
                    Text("Aucune note")
                        .foregroundStyle(.secondary)
                } else {
                    Text(displayed.note)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Informations") {
                LabeledContent(
                    "Créé le",
                    value: displayed.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
                LabeledContent("Statut") {
                    Text(displayed.isDone ? "Terminé" : "À faire")
                        .foregroundStyle(displayed.isDone ? .secondary : .primary)
                }
            }
        }
        .navigationTitle(displayed.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.toggle(displayed)
                } label: {
                    Label(
                        displayed.isDone ? "Marquer à faire" : "Marquer terminé",
                        systemImage: displayed.isDone ? "circle" : "checkmark.circle.fill"
                    )
                }
                .disabled(currentItem == nil)
            }
        }
        .overlay {
            if currentItem == nil {
                ContentUnavailableView(
                    "Élément supprimé",
                    systemImage: "trash",
                    description: Text("Revenez à la liste pour continuer.")
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: Item.samples[0])
            .environment(ItemListViewModel(store: InMemoryItemStore(items: Item.samples)))
    }
}
