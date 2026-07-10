import SwiftUI

/// The single source of truth for what worlds exist right now.
///
/// Every world is a content pack — a JSON file defining one world of
/// template-engine levels. Packs are gathered from two sources, and when the
/// same pack id appears in both, the highest version wins (ties break toward
/// the downloaded copy, which is never older than what shipped):
///
///   1. Downloaded — cached by PackSync in Application Support/Packs
///   2. Bundled    — shipped inside the app (Packs/ folder in the project)
///
/// A pack that fails to decode or validate is skipped silently: the app keeps
/// working with whatever content is good, and never shows an error to the child.
@MainActor
final class ContentLibrary: ObservableObject {
    static let shared = ContentLibrary()

    @Published private(set) var worlds: [World]

    private init() {
        worlds = Catalog.builtIn
        reload()
    }

    // MARK: Lookup

    func world(id: String) -> World? {
        worlds.first { $0.id == id }
    }

    /// Look up a level and its world from a level id like "N04" or "M07".
    func find(levelID: String) -> (World, LevelDefinition)? {
        for world in worlds {
            if let level = world.levels.first(where: { $0.id == levelID }) {
                return (world, level)
            }
        }
        return nil
    }

    /// The level that follows the given one on the same world map, if any.
    func level(after levelID: String) -> LevelDefinition? {
        guard let (world, level) = find(levelID: levelID),
              let index = world.levels.firstIndex(of: level),
              index + 1 < world.levels.count else { return nil }
        return world.levels[index + 1]
    }

    // MARK: Loading

    /// Re-scan every pack source and rebuild the world list. Called at
    /// startup and by PackSync whenever a download lands.
    func reload() {
        var best: [String: (pack: ContentPack, priority: Int)] = [:]

        // Priority: higher wins on version ties. Bundled 0, downloaded 1.
        for (priority, urls) in [bundledPackURLs(), downloadedPackURLs()].enumerated() {
            for url in urls {
                guard let pack = loadPack(at: url) else { continue }
                if let current = best[pack.id] {
                    let replaces = pack.version > current.pack.version
                        || (pack.version == current.pack.version && priority > current.priority)
                    if replaces { best[pack.id] = (pack, priority) }
                } else {
                    best[pack.id] = (pack, priority)
                }
            }
        }

        // Stable order: packs sorted by id. Two
        // packs claiming the same worldID would collide on the map, so only
        // the first (by pack id) is kept.
        var result = Catalog.builtIn
        var usedWorldIDs = Set(result.map(\.id))
        for (_, entry) in best.sorted(by: { $0.key < $1.key }) {
            guard !usedWorldIDs.contains(entry.pack.worldID) else { continue }
            usedWorldIDs.insert(entry.pack.worldID)
            result.append(entry.pack.world)
        }
        worlds = result
    }

    private func loadPack(at url: URL) -> ContentPack? {
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(ContentPack.self, from: data)
            try pack.validate()
            return pack
        } catch {
            // Bad packs are simply invisible; log for the curious developer.
            print("ContentLibrary: skipping pack at \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: Pack sources

    private func bundledPackURLs() -> [URL] {
        var urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        urls += Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Packs") ?? []
        return urls
    }

    private func downloadedPackURLs() -> [URL] {
        jsonFiles(in: Self.downloadsDirectory)
    }

    private func jsonFiles(in directory: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents.filter { $0.pathExtension.lowercased() == "json" }
    }

    /// Where PackSync caches downloaded packs. Created on first use.
    static var downloadsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Packs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
