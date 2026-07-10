import SwiftUI

/// Shared pieces for the template game engines. Everything a pack can show
/// on screen renders through PackVisualView, so every engine automatically
/// handles all three visual kinds: a single big emoji, a big text glyph
/// (numerals, letters), or a countable cluster of emoji.
struct PackVisualView: View {
    let visual: PackVisual
    var size: CGFloat = 120
    var tint: Color = Theme.cosmicBlue
    var highlighted: Bool = false

    var body: some View {
        if let text = visual.text {
            glyphTile(text)
        } else if let emoji = visual.emoji, let count = visual.count, count > 1 {
            clusterTile(emoji: emoji, count: count)
        } else {
            EmojiTile(emoji: visual.emoji ?? "❓", size: size, tint: tint, highlighted: highlighted)
        }
    }

    /// A numeral or letter in a glowing rounded square.
    private func glyphTile(_ text: String) -> some View {
        Text(text)
            .font(Theme.rounded(size * 0.5, weight: .heavy))
            .foregroundColor(.white)
            .minimumScaleFactor(0.5)
            .frame(width: size, height: size)
            .background(tileShape)
    }

    /// A countable group of the same emoji, laid out in rows of three.
    private func clusterTile(emoji: String, count: Int) -> some View {
        let columns = count <= 4 ? 2 : 3
        let rows = stride(from: 0, to: count, by: columns).map {
            Array(repeating: emoji, count: min(columns, count - $0))
        }
        let emojiSize = size * (count <= 4 ? 0.30 : 0.22)
        return VStack(spacing: size * 0.04) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: size * 0.05) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        Text(item).font(.system(size: emojiSize))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .background(tileShape)
    }

    private var tileShape: some View {
        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .fill(tint.opacity(highlighted ? 0.55 : 0.25))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .strokeBorder(
                        highlighted ? Theme.starYellow : .white.opacity(0.30),
                        lineWidth: highlighted ? 5 : 3
                    )
            )
            .shadow(color: highlighted ? Theme.starYellow.opacity(0.6) : tint.opacity(0.4),
                    radius: highlighted ? 14 : 8)
    }
}

/// Round-progress dots shared by the engines (same look as the bespoke games).
struct EngineProgressDots: View {
    let total: Int
    let filled: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Theme.starYellow : Color.white.opacity(0.25))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                    .shadow(color: index < filled ? Theme.starYellow.opacity(0.7) : .clear, radius: 5)
                    .scaleEffect(index == filled - 1 ? 1.25 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.5), value: filled)
            }
        }
    }
}

/// Numbers as Zibb speaks them while counting along.
enum SpokenNumber {
    private static let words = [
        "zero", "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
    ]

    static func word(_ number: Int) -> String {
        words.indices.contains(number) ? words[number] : "\(number)"
    }
}
