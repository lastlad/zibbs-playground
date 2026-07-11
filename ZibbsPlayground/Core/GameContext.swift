import SwiftUI

/// Handed to every mini-game. Games use it to narrate, play sounds, give
/// consistent praise/retry feedback, and report completion. Games must call
/// `finish()` exactly once when the child completes the activity — the host
/// screen then takes over with the celebration.
@MainActor
final class GameContext: ObservableObject {
    let level: LevelDefinition
    @Published private(set) var finished = false
    private(set) var earnedStars = 3

    /// Set by LevelHostView; games never touch this.
    var onFinish: ((Int) -> Void)?

    private var praiseIndex = Int.random(in: 0..<max(1, AppLines.shared.praise.count))
    private var retryIndex = Int.random(in: 0..<max(1, AppLines.shared.retry.count))

    init(level: LevelDefinition) {
        self.level = level
    }

    // MARK: Audio

    func say(_ text: String) {
        Narrator.shared.say(text)
    }

    func play(_ effect: SoundFX.Effect) {
        SoundFX.shared.play(effect)
    }

    func replayIntro() {
        play(.tap)
        say(level.intro)
    }

    // MARK: Feedback

    /// Correct answer: happy chime, plus a rotating spoken praise line
    /// (pass `speak: false` for mid-streak answers so Zibb isn't too chatty).
    func correct(speak: Bool = true, _ customLine: String? = nil) {
        play(.ding)
        guard speak else { return }
        if let customLine {
            say(customLine)
        } else {
            praiseIndex = (praiseIndex + 1) % AppLines.shared.praise.count
            say(AppLines.shared.praise[praiseIndex])
        }
    }

    /// Wrong answer: soft sound and gentle encouragement — never punishing.
    func tryAgain(_ hint: String? = nil) {
        play(.oops)
        if let hint {
            say(hint)
        } else {
            retryIndex = (retryIndex + 1) % AppLines.shared.retry.count
            say(AppLines.shared.retry[retryIndex])
        }
    }

    /// Report the level complete. Stars default to 3 — at this age every
    /// finished level is a triumph.
    func finish(stars: Int = 3) {
        guard !finished else { return }
        finished = true
        earnedStars = max(1, min(3, stars))
        onFinish?(earnedStars)
    }

}
