import SwiftUI

/// How a level is played. Zibb's Playground is fully template-driven, but
/// the seam for hand-written games is kept so a future world could slot in
/// a bespoke set-piece level by id.
enum GameSpec: Equatable {
    case bespoke
    case template(TemplateConfig)
}

/// One playable level: a single mini-game teaching a single concept.
struct LevelDefinition: Identifiable, Equatable {
    let id: String        // "<worldID><number>", e.g. "M01"
    let title: String     // Shown on the map and level header
    let concept: String   // The idea being taught (short)
    let emoji: String     // Map-node icon
    let intro: String     // Narrated by Zibb when the level starts
    var game: GameSpec = .bespoke
}

/// A themed planet containing a journey of levels.
struct World: Identifiable, Equatable {
    let id: String        // a pack's worldID
    let name: String
    let tagline: String
    let emoji: String
    let accent: Color
    let accentSecondary: Color
    var hasRing: Bool = false   // decorative ring on the home-screen planet
    let levels: [LevelDefinition]

    static func == (lhs: World, rhs: World) -> Bool { lhs.id == rhs.id }
}

enum Catalog {
    /// Zibb's Playground compiles no worlds in Swift — every world is a
    /// content pack (bundled in Packs/ or downloaded by PackSync).
    static let builtIn: [World] = []
}
