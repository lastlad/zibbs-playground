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
    private static let voiceVersionsKey = "zibbsPlayground.voice.versions"
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
            let file: String          // path relative to the repo root
            var voiceVersion: Int?    // maintained by tools/generate_voice.py
            var voiceFile: String?    // path to the pack's .voice.json index
        }
        /// The app-wide voice bank (praise lines, greetings, counting words)
        /// is versioned like a pack but isn't one.
        struct VoiceEntry: Codable {
            let version: Int
            let file: String
        }
        let schemaVersion: Int
        let packs: [Entry]
        var appVoice: VoiceEntry?
    }

    /// A pack's voice index: which clip files speak its lines. Written by
    /// tools/generate_voice.py next to the clips it references.
    private struct VoiceIndex: Codable {
        static let currentSchema = 1
        struct Line: Codable {
            let text: String
            let file: String   // "<textHash16>-<audioHash8>.mp3"
        }
        let schemaVersion: Int
        let id: String
        let version: Int
        let clipsPath: String  // clips directory relative to the repo root
        let lines: [Line]
    }

    /// Kick off a sync unless one ran recently (or is running now).
    static func syncIfDue(force: Bool = false) {
        let last = UserDefaults.standard.double(forKey: lastSyncKey)
        guard force || Date().timeIntervalSince1970 - last >= minimumInterval else { return }
        Task { await syncNow() }
    }

    /// Run a sync immediately and return once it finishes, ignoring the
    /// usual interval — for the home screen's refresh button. A call while
    /// another sync is running returns right away and changes nothing.
    static func syncNow() async {
        guard !running else { return }
        running = true
        await sync()
        running = false
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

        await syncVoice(manifest: manifest)
    }

    // MARK: - Voice banks

    /// Download any voice banks the manifest says are new or updated. Clips
    /// are content-addressed, so only files we don't already have (bundled or
    /// downloaded) transfer. A bank's version is recorded only after every
    /// one of its clips landed — a partial download changes nothing visible
    /// and simply resumes on the next sync. All failures are silent: a line
    /// without its clip falls back to text-to-speech in Narrator.
    private static func syncVoice(manifest: Manifest) async {
        var targets: [(id: String, version: Int, file: String)] = []
        if let appVoice = manifest.appVoice {
            targets.append(("app", appVoice.version, appVoice.file))
        }
        for entry in manifest.packs {
            if let version = entry.voiceVersion, let file = entry.voiceFile {
                targets.append((entry.id, version, file))
            }
        }

        var installed = installedVoiceVersions()
        var banksChanged = false

        for target in targets {
            if let have = installed[target.id], have >= target.version { continue }
            guard await downloadVoiceBank(target) else { continue }
            installed[target.id] = target.version
            banksChanged = true
        }

        UserDefaults.standard.set(installed, forKey: voiceVersionsKey)
        if banksChanged {
            VoiceBank.shared.reload()
        }
    }

    /// Fetch one bank's index and every clip it lists that we don't have yet.
    /// Returns false (recording nothing) unless the whole bank is present.
    private static func downloadVoiceBank(_ target: (id: String, version: Int, file: String)) async -> Bool {
        guard let indexURL = URL(string: target.file, relativeTo: baseURL),
              indexURL.host == baseURL.host else { return false }
        do {
            let (data, response) = try await session.data(from: indexURL)
            guard isOK(response) else { return false }
            let index = try JSONDecoder().decode(VoiceIndex.self, from: data)
            guard index.schemaVersion <= VoiceIndex.currentSchema,
                  index.id == target.id else { return false }

            for line in index.lines {
                guard downloadedClip(named: line.file) == nil,
                      !VoiceBank.shared.hasClip(filename: line.file) else { continue }
                guard await downloadClip(named: line.file, from: index.clipsPath) else { return false }
            }
            return true
        } catch {
            return false
        }
    }

    private static func downloadClip(named filename: String, from clipsPath: String) async -> Bool {
        guard isSafeClipFilename(filename),
              let url = URL(string: clipsPath + "/" + filename, relativeTo: baseURL),
              url.host == baseURL.host else { return false }
        do {
            let (data, response) = try await session.data(from: url)
            guard isOK(response), !data.isEmpty else { return false }

            // A re-recorded line keeps its text hash but changes its audio
            // suffix; drop the stale copy so the bank never plays old audio.
            if let textHash = filename.split(separator: "-").first {
                let contents = (try? FileManager.default.contentsOfDirectory(
                    at: VoiceBank.downloadsDirectory, includingPropertiesForKeys: nil)) ?? []
                for stale in contents where stale.lastPathComponent.hasPrefix("\(textHash)-") {
                    try? FileManager.default.removeItem(at: stale)
                }
            }

            let destination = VoiceBank.downloadsDirectory.appendingPathComponent(filename)
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func downloadedClip(named filename: String) -> URL? {
        let url = VoiceBank.downloadsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Clip filenames come from a downloaded index; accept only the exact
    /// shape the generator produces before touching the filesystem with them.
    private static func isSafeClipFilename(_ filename: String) -> Bool {
        let parts = filename.split(separator: ".")
        guard parts.count == 2, parts[1] == "mp3" else { return false }
        let hashes = parts[0].split(separator: "-")
        guard hashes.count == 2, hashes[0].count == 16, hashes[1].count == 8 else { return false }
        return hashes.allSatisfy { $0.allSatisfy(\.isHexDigit) }
    }

    private static func installedVoiceVersions() -> [String: Int] {
        let raw = UserDefaults.standard.dictionary(forKey: voiceVersionsKey) ?? [:]
        return raw.compactMapValues { $0 as? Int }
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
