import AVFoundation

/// Zibb's voice, fully offline.
///
/// Every line is looked up in the VoiceBank first — a pre-generated clip of
/// Zibb's real voice (see tools/generate_voice.py). Lines without a clip fall
/// back to the on-device speech synthesizer, so narration always works: a
/// brand-new pack sounds robotic for a sync cycle at worst, never silent.
///
/// Public behavior is unchanged from the TTS-only days: `say` interrupts
/// whatever is playing (kids tap fast), `queue` speaks after the current line
/// finishes, and a single FIFO drives both clips and synthesized lines so the
/// two sources mix freely mid-sentence-sequence.
/// The AV delegate protocols imply Sendable; Narrator is safe because all
/// mutable state is touched on the main thread only (callbacks hop to main).
final class Narrator: NSObject, @unchecked Sendable {
    static let shared = Narrator()

    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    /// What is speaking right now, so delegate callbacks for a line we
    /// already interrupted can't advance the queue.
    private enum Current {
        case clip(AVAudioPlayer)
        case speech(AVSpeechUtterance)
    }
    private var current: Current?
    private var pending: [String] = []

    private override init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // Prefer an enhanced-quality English voice if one is installed on the iPad.
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        voice = english.first { $0.quality == .enhanced && $0.language == "en-US" }
            ?? AVSpeechSynthesisVoice(language: "en-US")
        super.init()
        synthesizer.delegate = self
    }

    /// Speak a line, interrupting whatever was being said (kids tap fast).
    func say(_ text: String, interrupt: Bool = true) {
        if interrupt {
            stopCurrent(clearQueue: true)
        }
        pending.append(text)
        playNextIfIdle()
    }

    /// Speak after the current line finishes (for multi-sentence sequences).
    func queue(_ text: String) {
        say(text, interrupt: false)
    }

    func stop() {
        stopCurrent(clearQueue: true)
    }

    // MARK: Playback

    private func playNextIfIdle() {
        guard current == nil, !pending.isEmpty else { return }
        let text = pending.removeFirst()

        if let url = VoiceBank.shared.clipURL(for: text),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.delegate = self
            current = .clip(player)
            player.play()
            return
        }

        #if DEBUG
        print("Narrator: no voice clip, falling back to TTS for: \(text)")
        #endif
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.44
        utterance.pitchMultiplier = 1.12
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        current = .speech(utterance)
        synthesizer.speak(utterance)
    }

    /// Silence whatever is playing. `current` is cleared before stopping so
    /// the resulting delegate callbacks are ignored.
    private func stopCurrent(clearQueue: Bool) {
        if clearQueue { pending.removeAll() }
        guard let playing = current else { return }
        current = nil
        switch playing {
        case .clip(let player):
            player.stop()
        case .speech:
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Delegate callbacks land here; only the line we still consider current
    /// may advance the queue.
    private func finished(where matches: @escaping (Current) -> Bool) {
        DispatchQueue.main.async {
            guard let playing = self.current, matches(playing) else { return }
            self.current = nil
            self.playNextIfIdle()
        }
    }
}

extension Narrator: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        finished { if case .clip(let currentPlayer) = $0 { return currentPlayer === player }; return false }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        finished { if case .clip(let currentPlayer) = $0 { return currentPlayer === player }; return false }
    }
}

extension Narrator: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finished { if case .speech(let currentUtterance) = $0 { return currentUtterance === utterance }; return false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finished { if case .speech(let currentUtterance) = $0 { return currentUtterance === utterance }; return false }
    }
}
