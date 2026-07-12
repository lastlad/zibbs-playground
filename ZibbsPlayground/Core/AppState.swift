import SwiftUI

enum Screen: Equatable {
    case home
    case world(String)   // a pack's worldID, e.g. "M"
    case level(String)   // level id, e.g. "M01"
}

/// Global navigation + progress. Progress is stars-per-level, persisted locally
/// so everything works offline and survives relaunches.
@MainActor
final class AppState: ObservableObject {
    @Published var screen: Screen = .home
    @Published private(set) var stars: [String: Int]
    @Published private(set) var seenWorlds: Set<String>

    private static let storageKey = "zibbsPlayground.progress.v1"
    private static let seenWorldsKey = "zibbsPlayground.seenWorlds.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            stars = decoded
        } else {
            stars = [:]
        }
        if let saved = UserDefaults.standard.stringArray(forKey: Self.seenWorldsKey) {
            seenWorlds = Set(saved)
        } else {
            // First run (or upgrade): everything already installed counts as
            // seen, so NEW badges only ever mark worlds that arrive later.
            seenWorlds = Set(ContentLibrary.shared.worlds.map(\.id))
            UserDefaults.standard.set(Array(seenWorlds), forKey: Self.seenWorldsKey)
        }
    }

    func stars(for levelID: String) -> Int {
        stars[levelID] ?? 0
    }

    func record(stars newStars: Int, for levelID: String) {
        let best = max(newStars, stars[levelID] ?? 0)
        stars[levelID] = best
        if let data = try? JSONEncoder().encode(stars) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// The first level of each world is always open; each later level unlocks
    /// once the one before it has been completed.
    func isUnlocked(_ level: LevelDefinition, in world: World) -> Bool {
        guard let index = world.levels.firstIndex(of: level) else { return false }
        if index == 0 { return true }
        return stars(for: world.levels[index - 1].id) > 0
    }

    func starsEarned(in world: World) -> Int {
        world.levels.reduce(0) { $0 + stars(for: $1.id) }
    }

    /// True for a world that beamed down over the air and hasn't been opened
    /// yet — the home screen marks it with a NEW badge.
    func isNew(_ world: World) -> Bool {
        !seenWorlds.contains(world.id)
    }

    var totalStars: Int {
        ContentLibrary.shared.worlds.reduce(0) { $0 + starsEarned(in: $1) }
    }

    // MARK: Navigation helpers

    func goHome() {
        Narrator.shared.stop()
        screen = .home
    }

    func open(world: World) {
        Narrator.shared.stop()
        if !seenWorlds.contains(world.id) {
            seenWorlds.insert(world.id)
            UserDefaults.standard.set(Array(seenWorlds), forKey: Self.seenWorldsKey)
        }
        screen = .world(world.id)
    }

    func open(level: LevelDefinition) {
        Narrator.shared.stop()
        screen = .level(level.id)
    }
}
