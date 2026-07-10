import Foundation

/// Background content updates, offline-first.
///
/// When the app comes to the foreground and the device happens to be online,
/// PackSync fetches a tiny manifest listing the packs published in the app's
/// GitHub repository, downloads any it doesn't have yet (or has an older
/// version of), validates them, and caches them in Application Support where
/// ContentLibrary picks them up. New worlds appear on the home screen —
/// no rebuild, no App Store.
///
/// Publishing content is just: add/update a pack JSON in the repo, bump its
/// version in packs/manifest.json, push to main.
///
/// The child never sees any of this. No connection, a slow server, a bad
/// file — every failure path is silent and the app plays whatever content
/// it already has.
@MainActor
enum PackSync {
    /// Files are served straight off the repo's main branch.
    private static let baseURL = URL(string: "https://raw.githubusercontent.com/lastlad/zibbs-playground/main/")!
    private static var manifestURL: URL { baseURL.appendingPathComponent("packs/manifest.json") }

    private static let lastSyncKey = "zibbsPlayground.packs.lastSync"
    private static let versionsKey = "zibbsPlayground.packs.versions"
    private static let minimumInterval: TimeInterval = 4 * 60 * 60

    private static var running = false

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    private struct Manifest: Codable {
        struct Entry: Codable {
            let id: String
            let version: Int
            let file: String   // path relative to the repo root
        }
        let schemaVersion: Int
        let packs: [Entry]
    }

    /// Kick off a sync unless one ran recently (or is running now).
    static func syncIfDue(force: Bool = false) {
        guard !running else { return }
        let last = UserDefaults.standard.double(forKey: lastSyncKey)
        guard force || Date().timeIntervalSince1970 - last >= minimumInterval else { return }
        running = true
        Task {
            await sync()
            running = false
        }
    }

    private static func sync() async {
        guard let manifest = await fetchManifest() else { return }

        // Only a successful manifest fetch counts as "synced" — an offline
        // attempt costs one fast-failing request and retries next foreground.
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncKey)

        var installed = installedVersions()
        var libraryNeedsReload = false

        for entry in manifest.packs {
            if let have = installed[entry.id], have >= entry.version { continue }
            guard let pack = await download(entry) else { continue }
            installed[entry.id] = pack.version
            libraryNeedsReload = true
        }

        UserDefaults.standard.set(installed, forKey: versionsKey)
        if libraryNeedsReload {
            ContentLibrary.shared.reload()
        }
    }

    private static func fetchManifest() async -> Manifest? {
        do {
            let (data, response) = try await session.data(from: manifestURL)
            guard isOK(response) else { return nil }
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            guard manifest.schemaVersion <= ContentPack.currentSchema else { return nil }
            return manifest
        } catch {
            return nil
        }
    }

    /// Fetch one pack, validate it end to end, and cache it atomically.
    /// Returns nil (changing nothing) on any problem.
    private static func download(_ entry: Manifest.Entry) async -> ContentPack? {
        guard let url = URL(string: entry.file, relativeTo: baseURL),
              url.host == baseURL.host else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard isOK(response) else { return nil }
            let pack = try JSONDecoder().decode(ContentPack.self, from: data)
            try pack.validate()
            guard pack.id == entry.id else { return nil }
            let destination = ContentLibrary.downloadsDirectory
                .appendingPathComponent("\(pack.id).json")
            try data.write(to: destination, options: .atomic)
            return pack
        } catch {
            return nil
        }
    }

    private static func installedVersions() -> [String: Int] {
        let raw = UserDefaults.standard.dictionary(forKey: versionsKey) ?? [:]
        return raw.compactMapValues { $0 as? Int }
    }

    private static func isOK(_ response: URLResponse) -> Bool {
        (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
    }
}
