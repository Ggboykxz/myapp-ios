import Foundation

/// Entité métier principale de l'application.
///
/// `Codable` permet la persistance JSON, `Hashable` la navigation
/// (`NavigationLink(value:)` / `navigationDestination(for:)`).
struct Item: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var note: String
    var isDone: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

extension Item {
    /// Jeu de données statique réservé aux previews et aux tests.
    static let samples: [Item] = [
        Item(title: "Configurer le compte développeur", note: "Team Apple Developer"),
        Item(title: "Créer les icônes d'app", note: "Export 1024×1024", isDone: true),
        Item(title: "Relire la charte graphique", createdAt: .now.addingTimeInterval(-86_400))
    ]
}
