import SwiftUI
import Observation

/// Écran principal : liste filtrable/cherchable des éléments.
struct ContentView: View {
    @Environment(ItemListViewModel.self) private var model

    @State private var isNewItemPresented = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            content
                .navigationTitle("MyApp")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isNewItemPresented = true
                        } label: {
                            Label("Nouvel élément", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isNewItemPresented) {
                    NewItemSheet()
                }
        }
        .task {
            await model.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .idle, .loading:
            ProgressView("Chargement…")

        case .failed(let message):
            ContentUnavailableView {
                Label("Chargement impossible", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Réessayer") {
                    Task { await model.load() }
                }
                .buttonStyle(.borderedProminent)
            }

        case .loaded:
            list
        }
    }

    private var list: some View {
        @Bindable var model = model

        return List {
            Section {
                Picker("Filtre", selection: $model.filter) {
                    ForEach(ItemListViewModel.Filter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Éléments") {
                if model.visibleItems.isEmpty {
                    ContentUnavailableView.search(text: model.searchText)
                } else {
                    ForEach(model.visibleItems) { item in
                        NavigationLink(value: item) {
                            ItemRow(item: item)
                        }
                    }
                    .onDelete(perform: model.delete)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $model.searchText, prompt: "Rechercher")
        .navigationDestination(for: Item.self) { item in
            ItemDetailView(item: item)
        }
        .safeAreaInset(edge: .bottom) {
            if model.remainingCount > 0 {
                Text("^[\(model.remainingCount) element](inflect: true) à faire")
                    .font(.footnote.monospacedDigit())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }
}

#Preview("Liste") {
    ContentView()
        .environment(ItemListViewModel(store: InMemoryItemStore(items: Item.samples)))
}

#Preview("Vide") {
    ContentView()
        .environment(ItemListViewModel())
}
