import SwiftUI

/// Content packs: whole worlds defined in JSON instead of Swift.
///
/// A pack decodes into a `ContentPack`, validates, and converts into the same
/// `World`/`LevelDefinition` values the rest of the app already understands —
/// its levels are played by the template engines in Games/Engines. Packs come
/// from two places (see ContentLibrary): bundled with the app or downloaded
/// by PackSync. Every world in Zibb's Playground is a pack. The JSON format
/// is documented in packs/SCHEMA.md at the repo root.

// MARK: - Errors

struct PackError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// MARK: - Pack document

struct ContentPack: Codable, Equatable {
    static let currentSchema = 1

    let schemaVersion: Int
    let id: String              // globally unique, e.g. "world.numbers"
    let version: Int            // bump so devices re-download the pack
    let worldID: String         // short unique prefix for level ids, e.g. "M"
    let name: String
    let tagline: String
    let emoji: String
    let accent: PackColor
    let accentSecondary: PackColor
    var ring: Bool?             // draw a planetary ring on the home card
    let levels: [PackLevel]

    /// Structural checks beyond what Codable enforces. A pack that fails any
    /// of these is skipped entirely — a half-broken world must never reach
    /// the child.
    func validate() throws {
        guard schemaVersion >= 1, schemaVersion <= Self.currentSchema else {
            throw PackError("Pack \(id): schemaVersion \(schemaVersion) is not supported by this app version.")
        }
        guard !worldID.isEmpty else {
            throw PackError("Pack \(id): worldID is empty.")
        }
        guard !levels.isEmpty, levels.count <= 12 else {
            throw PackError("Pack \(id): needs 1–12 levels (the journey map gets crowded past 12).")
        }
        guard Set(levels.map(\.id)).count == levels.count else {
            throw PackError("Pack \(id): level ids are not unique.")
        }
        for level in levels {
            guard level.id.hasPrefix(worldID) else {
                throw PackError("Pack \(id): level id '\(level.id)' must start with worldID '\(worldID)'.")
            }
            try level.template.validate(levelID: level.id)
        }
    }

    /// The playable world this pack describes.
    var world: World {
        World(
            id: worldID,
            name: name,
            tagline: tagline,
            emoji: emoji,
            accent: accent.color,
            accentSecondary: accentSecondary.color,
            hasRing: ring ?? false,
            levels: levels.map { level in
                LevelDefinition(
                    id: level.id,
                    title: level.title,
                    concept: level.concept,
                    emoji: level.emoji,
                    intro: level.intro,
                    game: .template(level.template)
                )
            }
        )
    }
}

// MARK: - Colors

/// Named palette colors so pack JSON stays readable and always on-theme.
enum PackColor: String, Codable, Equatable, CaseIterable {
    case green, blue, purple, orange, pink, yellow, ice, red

    var color: Color {
        switch self {
        case .green:  return Theme.alienGreen
        case .blue:   return Theme.cosmicBlue
        case .purple: return Theme.nebulaPurple
        case .orange: return Theme.rocketOrange
        case .pink:   return Theme.cometPink
        case .yellow: return Theme.starYellow
        case .ice:    return Theme.iceBlue
        case .red:    return Theme.softRed
        }
    }
}

// MARK: - Levels

struct PackLevel: Equatable {
    let id: String
    let title: String
    let concept: String
    let emoji: String
    let intro: String
    let template: TemplateConfig
}

extension PackLevel: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, concept, emoji, intro, template
        case tapChoice, sortBins, matchPairs, countTap, orderSequence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        concept = try container.decode(String.self, forKey: .concept)
        emoji = try container.decode(String.self, forKey: .emoji)
        intro = try container.decode(String.self, forKey: .intro)

        // The "template" key names the engine; the config object lives under
        // a sibling key of the same name.
        let name = try container.decode(String.self, forKey: .template)
        switch name {
        case "tapChoice":
            template = .tapChoice(try container.decode(TapChoiceConfig.self, forKey: .tapChoice))
        case "sortBins":
            template = .sortBins(try container.decode(SortBinsConfig.self, forKey: .sortBins))
        case "matchPairs":
            template = .matchPairs(try container.decode(MatchPairsConfig.self, forKey: .matchPairs))
        case "countTap":
            template = .countTap(try container.decode(CountTapConfig.self, forKey: .countTap))
        case "orderSequence":
            template = .orderSequence(try container.decode(SequenceConfig.self, forKey: .orderSequence))
        default:
            throw PackError("Level \(id): unknown template '\(name)'. This app version knows: tapChoice, sortBins, matchPairs, countTap, orderSequence.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(concept, forKey: .concept)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(intro, forKey: .intro)
        switch template {
        case .tapChoice(let config):
            try container.encode("tapChoice", forKey: .template)
            try container.encode(config, forKey: .tapChoice)
        case .sortBins(let config):
            try container.encode("sortBins", forKey: .template)
            try container.encode(config, forKey: .sortBins)
        case .matchPairs(let config):
            try container.encode("matchPairs", forKey: .template)
            try container.encode(config, forKey: .matchPairs)
        case .countTap(let config):
            try container.encode("countTap", forKey: .template)
            try container.encode(config, forKey: .countTap)
        case .orderSequence(let config):
            try container.encode("orderSequence", forKey: .template)
            try container.encode(config, forKey: .orderSequence)
        }
    }
}

// MARK: - Template configs

enum TemplateConfig: Equatable {
    case tapChoice(TapChoiceConfig)
    case sortBins(SortBinsConfig)
    case matchPairs(MatchPairsConfig)
    case countTap(CountTapConfig)
    case orderSequence(SequenceConfig)

    func validate(levelID: String) throws {
        switch self {
        case .tapChoice(let config):     try config.validate(levelID: levelID)
        case .sortBins(let config):      try config.validate(levelID: levelID)
        case .matchPairs(let config):    try config.validate(levelID: levelID)
        case .countTap(let config):      try config.validate(levelID: levelID)
        case .orderSequence(let config): try config.validate(levelID: levelID)
        }
    }
}

/// What a game piece looks like: exactly one of a single big emoji, a big
/// text glyph (numerals, letters), or a countable cluster of `count` emoji.
struct PackVisual: Codable, Equatable {
    var emoji: String?
    var text: String?
    var count: Int?

    var isValid: Bool {
        if let count { return emoji != nil && text == nil && (1...10).contains(count) }
        return (emoji != nil) != (text != nil)   // exactly one of the two
    }
}

/// Rounds of "tap the right one": a question and 2–4 tappable options.
struct TapChoiceConfig: Codable, Equatable {
    struct Round: Codable, Equatable {
        let question: String
        var spoken: String?       // narration, defaults to `question`
        let options: [PackVisual]
        let answer: Int           // index into `options`
        var success: String?      // spoken on the right tap
        var hint: String?         // spoken on a wrong tap
    }
    let rounds: [Round]
    var shuffleOptions: Bool?     // default true

    func validate(levelID: String) throws {
        guard !rounds.isEmpty else { throw PackError("Level \(levelID): tapChoice has no rounds.") }
        for (index, round) in rounds.enumerated() {
            guard (2...4).contains(round.options.count) else {
                throw PackError("Level \(levelID) round \(index + 1): needs 2–4 options.")
            }
            guard round.options.indices.contains(round.answer) else {
                throw PackError("Level \(levelID) round \(index + 1): answer index \(round.answer) is out of range.")
            }
            guard round.options.allSatisfy(\.isValid) else {
                throw PackError("Level \(levelID) round \(index + 1): each option needs exactly one of emoji or text (count 1–10 only with emoji).")
            }
        }
    }
}

/// Drag every item into its matching bin. Items appear in waves so the tray
/// never overwhelms.
struct SortBinsConfig: Codable, Equatable {
    struct Bin: Codable, Equatable {
        let label: String
        let emoji: String
    }
    struct Item: Codable, Equatable {
        var emoji: String?
        var text: String?
        var count: Int?
        let bin: Int              // index into `bins`
        var name: String?         // spoken on a correct drop
        var visual: PackVisual { PackVisual(emoji: emoji, text: text, count: count) }
    }
    let prompt: String
    var spoken: String?
    let bins: [Bin]
    let items: [Item]
    var perWave: Int?             // items in the tray at once, default 4

    func validate(levelID: String) throws {
        guard (2...3).contains(bins.count) else {
            throw PackError("Level \(levelID): sortBins needs 2 or 3 bins.")
        }
        guard !items.isEmpty else { throw PackError("Level \(levelID): sortBins has no items.") }
        for (index, item) in items.enumerated() {
            guard bins.indices.contains(item.bin) else {
                throw PackError("Level \(levelID) item \(index + 1): bin index \(item.bin) is out of range.")
            }
            guard item.visual.isValid else {
                throw PackError("Level \(levelID) item \(index + 1): needs exactly one of emoji or text (count 1–10 only with emoji).")
            }
        }
        if let perWave { guard (2...4).contains(perWave) else {
            throw PackError("Level \(levelID): perWave must be 2–4.")
        } }
    }
}

/// Drag each loose piece onto the target it belongs with.
struct MatchPairsConfig: Codable, Equatable {
    struct Pair: Codable, Equatable {
        let drag: PackVisual
        let target: PackVisual
        var success: String?      // spoken when this pair is matched
    }
    let prompt: String
    var spoken: String?
    let pairs: [Pair]
    var perRound: Int?            // pairs on screen at once, default 3

    func validate(levelID: String) throws {
        guard !pairs.isEmpty else { throw PackError("Level \(levelID): matchPairs has no pairs.") }
        for (index, pair) in pairs.enumerated() {
            guard pair.drag.isValid, pair.target.isValid else {
                throw PackError("Level \(levelID) pair \(index + 1): drag and target each need exactly one of emoji or text (count 1–10 only with emoji).")
            }
        }
        if let perRound { guard (2...3).contains(perRound) else {
            throw PackError("Level \(levelID): perRound must be 2 or 3.")
        } }
    }
}

/// Tap each item once while Zibb counts along out loud.
struct CountTapConfig: Codable, Equatable {
    struct Round: Codable, Equatable {
        let prompt: String
        var spoken: String?
        let emoji: String
        let count: Int            // 1...10
        var success: String?      // spoken when the last one is tapped
    }
    let rounds: [Round]

    func validate(levelID: String) throws {
        guard !rounds.isEmpty else { throw PackError("Level \(levelID): countTap has no rounds.") }
        for (index, round) in rounds.enumerated() {
            guard (1...10).contains(round.count) else {
                throw PackError("Level \(levelID) round \(index + 1): count must be 1–10.")
            }
            guard !round.emoji.isEmpty else {
                throw PackError("Level \(levelID) round \(index + 1): emoji is empty.")
            }
        }
    }
}

/// Tap shuffled items in their correct order; each lands in the next slot.
struct SequenceConfig: Codable, Equatable {
    struct Round: Codable, Equatable {
        let prompt: String
        var spoken: String?
        let items: [PackVisual]   // listed in the CORRECT order
        var names: [String]?      // spoken as each item is placed, parallel to items
        var success: String?
    }
    let rounds: [Round]

    func validate(levelID: String) throws {
        guard !rounds.isEmpty else { throw PackError("Level \(levelID): orderSequence has no rounds.") }
        for (index, round) in rounds.enumerated() {
            guard (3...6).contains(round.items.count) else {
                throw PackError("Level \(levelID) round \(index + 1): needs 3–6 items.")
            }
            guard round.items.allSatisfy(\.isValid) else {
                throw PackError("Level \(levelID) round \(index + 1): each item needs exactly one of emoji or text (count 1–10 only with emoji).")
            }
            if let names = round.names, names.count != round.items.count {
                throw PackError("Level \(levelID) round \(index + 1): names must have one entry per item.")
            }
        }
    }
}
