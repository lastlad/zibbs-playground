import Foundation

/// Every line the app itself speaks (as opposed to lines authored in content
/// packs), loaded from the bundled Voice/app-lines.json.
///
/// That JSON is the single source of truth shared with tools/generate_voice.py,
/// which pre-generates a voice clip for each line — including every expansion
/// of the {world}/{stars}/{word} templates. Keeping the lines in data means
/// the generator can never drift from what the app actually says. If you add
/// a spoken line to the app, add it here, never as a free-form Swift string.
struct AppLines: Decodable {
    let praise: [String]
    let retry: [String]
    let homeGreeting: String
    let mapWelcome: String
    let levelLocked: String
    let newWorld: String
    let sortComplete: String
    let countWords: [String]
    let countSuccess: String
    let celebration: [String]
    let celebrationFinale: String

    static let shared: AppLines = load()

    // MARK: Template expansion

    func mapWelcome(world: String) -> String {
        mapWelcome.replacingOccurrences(of: "{world}", with: world)
    }

    func newWorld(world: String) -> String {
        newWorld.replacingOccurrences(of: "{world}", with: world)
    }

    func celebration(stars: Int) -> String {
        let line = celebration.randomElement() ?? "Hooray!"
        return line.replacingOccurrences(of: "{stars}", with: "\(stars)")
    }

    func celebrationFinale(world: String) -> String {
        celebrationFinale.replacingOccurrences(of: "{world}", with: world)
    }

    /// The word Zibb says for a number while counting ("three").
    func countWord(_ number: Int) -> String {
        countWords.indices.contains(number) ? countWords[number] : "\(number)"
    }

    func countSuccess(word: String) -> String {
        countSuccess.replacingOccurrences(of: "{word}", with: word)
    }

    // MARK: Loading

    private static func load() -> AppLines {
        let url = Bundle.main.url(forResource: "app-lines", withExtension: "json")
            ?? Bundle.main.url(forResource: "app-lines", withExtension: "json", subdirectory: "Voice")
        if let url,
           let data = try? Data(contentsOf: url),
           let lines = try? JSONDecoder().decode(AppLines.self, from: data) {
            return lines
        }
        // A missing or broken file is a build mistake, but the child must
        // still get a working app — fall back to a minimal spoken set.
        print("AppLines: bundled app-lines.json missing or invalid; using fallback lines")
        return AppLines(
            praise: ["Great job, Explorer!"],
            retry: ["Almost! Try again!"],
            homeGreeting: "Hi Explorer! Welcome to my playground!",
            mapWelcome: "Welcome to {world}!",
            levelLocked: "Finish the level before this one to unlock it!",
            newWorld: "Wow! A new world just landed!",
            sortComplete: "You sorted everything! Amazing!",
            countWords: ["zero", "one", "two", "three", "four", "five",
                         "six", "seven", "eight", "nine", "ten", "eleven", "twelve"],
            countSuccess: "That's {word}! Great counting, Explorer!",
            celebration: ["Hooray! You earned {stars} stars!"],
            celebrationFinale: "Hooray! You finished every adventure on {world}!"
        )
    }
}
