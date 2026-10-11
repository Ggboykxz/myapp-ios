import SwiftUI
import Observation

/// Point d'entrée de l'application.
///
/// Le ViewModel est créé ici (et non dans la vue) pour pouvoir injecter
/// le magasin de données réel. Les previews et les tests injectent leur
/// propre magasin via `ItemListViewModel(store:)`.
@main
struct MyAppApp: App {
    @State private var model = ItemListViewModel(
        store: JSONFileItemStore.appStorage()
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
