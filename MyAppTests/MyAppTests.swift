import XCTest
@testable import MyApp

/// Tests unitaires du ViewModel : le magasin est remplacé par un double
/// en mémoire, aucune UI n'est impliquée.
final class ItemListViewModelTests: XCTestCase {

    private struct StubStore: ItemStore {
        let initialItems: [Item]

        init(initialItems: [Item] = []) {
            self.initialItems = initialItems
        }

        func load() async throws -> [Item] { initialItems }
        func save(_ items: [Item]) async throws {}
    }

    // MARK: - Chargement

    func testLoadSucceeds() async {
        let store = StubStore(initialItems: Item.samples)
        let viewModel = ItemListViewModel(store: store)

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.items.count, Item.samples.count)
    }

    func testLoadFailureSetsFailedState() async {
        struct FailingStore: ItemStore {
            func load() async throws -> [Item] {
                throw CocoaError(.fileReadCorruptFile)
            }
            func save(_ items: [Item]) async throws {}
        }

        let viewModel = ItemListViewModel(store: FailingStore())
        await viewModel.load()

        guard case .failed = viewModel.loadState else {
            return XCTFail("Un échec de chargement doit produire l'état .failed")
        }
    }

    // MARK: - Mutations

    func testAddItemAppendsAndTrimsWhitespace() {
        let viewModel = ItemListViewModel(store: StubStore())

        viewModel.addItem(title: "  Acheter du lait  ", note: "  Demi-écrémé  ")

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].title, "Acheter du lait")
        XCTAssertEqual(viewModel.items[0].note, "Demi-écrémé")
        XCTAssertFalse(viewModel.items[0].isDone)
    }

    func testAddItemIgnoresBlankTitle() {
        let viewModel = ItemListViewModel(store: StubStore())

        viewModel.addItem(title: "   \n ")

        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testToggleFlipsDoneState() {
        let viewModel = ItemListViewModel(store: StubStore())
        viewModel.addItem(title: "Tâche")

        viewModel.toggle(viewModel.items[0])

        XCTAssertTrue(viewModel.items[0].isDone)
        XCTAssertEqual(viewModel.remainingCount, 0)
    }

    func testToggleOnUnknownItemIsNoOp() {
        let viewModel = ItemListViewModel(store: StubStore())
        viewModel.addItem(title: "Tâche")

        viewModel.toggle(Item(title: "Inconnu"))

        XCTAssertFalse(viewModel.items[0].isDone)
    }

    // MARK: - Filtres et recherche

    func testFilterAndSearchNarrowVisibleItems() {
        let viewModel = ItemListViewModel(store: StubStore())
        viewModel.addItem(title: "Payer la facture")
        viewModel.addItem(title: "Appeler le dentiste")
        viewModel.toggle(viewModel.items[0])

        viewModel.filter = .active
        XCTAssertEqual(viewModel.visibleItems.map(\.title), ["Appeler le dentiste"])

        viewModel.filter = .done
        XCTAssertEqual(viewModel.visibleItems.map(\.title), ["Payer la facture"])

        viewModel.filter = .all
        viewModel.searchText = "dentiste"
        XCTAssertEqual(viewModel.visibleItems.map(\.title), ["Appeler le dentiste"])
    }

    func testDeleteRemovesOnlySelectedItems() {
        let viewModel = ItemListViewModel(store: StubStore())
        viewModel.addItem(title: "Premier")
        viewModel.addItem(title: "Second")

        // `visibleItems` est trié du plus récent au plus ancien : l'index 0
        // correspond donc à "Second".
        viewModel.delete(at: IndexSet(integer: 0))

        XCTAssertEqual(viewModel.items.map(\.title), ["Premier"])
    }
}
