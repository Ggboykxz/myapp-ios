import SwiftUI

/// Constantes visuelles centralisées : une seule source de vérité pour
/// rayons, espacements et couleurs dérivées.
enum Theme {
    static let cornerRadius: CGFloat = 14
    static let spacing: CGFloat = 12
    static let listRowSpacing: CGFloat = 4

    static func symbolColor(isDone: Bool) -> Color {
        isDone ? .secondary : .accentColor
    }
}
