import Foundation
import Observation

/// ViewModel de la liste : exposure l'état observable et reçoit les
/// intentions de l'utilisateur. Aucune dépendance à SwiftUI ici, ce qui
/// rend la classe testable unitairement.
@Observable
final class ItemListViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case active
        case done

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Toutes"
            case .active: return "À faire"
            case .done: return "Terminées"
            }
        }
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private let store: any ItemStore

    private(set) var items: [Item] = []
    private(set) var loadState: LoadState = .idle

    var filter: Filter = .all
    var searchText: String = ""

    init(store: any ItemStore = InMemoryItemStore()) {
        self.store = store
    }

    // MARK: - Dérivés

    var visibleItems: [Item] {
        items
            .filter { item in
                switch filter {
                case .all: return true
                case .active: return !item.isDone
                case .done: return item.isDone
                }
            }
            .filter { searchText.isEmpty || itemMatchesSearch($0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var remainingCount: Int {
        items.filter { !$0.isDone }.count
    }

    // MARK: - Cycle de vie

    func load() async {
        loadState = .loading
        do {
            items = try await store.load()
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Intentions

    func addItem(title: String, note: String = "") {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        items.append(Item(title: trimmedTitle, note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        persist()
    }

    func toggle(_ item: Item) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        persist()
    }

    func delete(at offsets: IndexSet) {
        let targets = offsets.compactMap { index -> Item? in
            visibleItems.indices.contains(index) ? visibleItems[index] : nil
        }
        items.removeAll { target in targets.contains(where: { $0.id == target.id }) }
        persist()
    }

    // MARK: - Privé

    private func itemMatchesSearch(_ item: Item) -> Bool {
        let needle = searchText.lowercased()
        return item.title.lowercased().contains(needle)
            || item.note.lowercased().contains(needle)
    }

    private func persist() {
        let snapshot = items
        Task {
            try? await store.save(snapshot)
        }
    }
}
