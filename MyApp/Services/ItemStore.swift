import Foundation

/// Contrat d'accès aux données : permet de substituer un magasin en mémoire
/// (previews, tests) par un magasin fichier (application).
protocol ItemStore: Sendable {
    func load() async throws -> [Item]
    func save(_ items: [Item]) async throws
}

/// Magasin éphémère, utilisé par les previews et les tests unitaires.
actor InMemoryItemStore: ItemStore {
    private var items: [Item]

    init(items: [Item] = []) {
        self.items = items
    }

    func load() async throws -> [Item] {
        items
    }

    func save(_ items: [Item]) async throws {
        self.items = items
    }
}

/// Magasin persistant : fichier JSON dans le répertoire Application Support.
actor JSONFileItemStore: ItemStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Magasin par défaut de l'application (`<Application Support>/items.json`).
    static func appStorage() -> JSONFileItemStore {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory

        return JSONFileItemStore(
            fileURL: base.appendingPathComponent("items.json", isDirectory: false)
        )
    }

    func load() async throws -> [Item] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Item].self, from: data)
    }

    func save(_ items: [Item]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(items)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
    }
}
