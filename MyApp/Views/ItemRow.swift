import SwiftUI

/// Ligne de liste : rendu optimisé pour un balayage rapide du pouce.
struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.spacing) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
                .foregroundStyle(Theme.symbolColor(isDone: item.isDone))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.listRowSpacing) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Text(item.createdAt, format: .dateTime.month().day())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(item.isDone ? .isSelected : [])
    }
}

#Preview {
    List {
        ItemRow(item: Item.samples[0])
        ItemRow(item: Item.samples[1])
    }
}
