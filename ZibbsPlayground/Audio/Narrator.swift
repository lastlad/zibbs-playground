import AVFoundation

/// Fully-offline voice narration using the on-device speech synthesizer.
/// Kid-tuned: slightly slower rate, slightly higher pitch, warm phrasing.
final class Narrator {
    static let shared = Narrator()

    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // Prefer an enhanced-quality English voice if one is installed on the iPad.
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        voice = english.first { $0.quality == .enhanced && $0.language == "en-US" }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Speak a line, interrupting whatever was being said (kids tap fast).
    func say(_ text: String, interrupt: Bool = true) {
        if interrupt, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.44
        utterance.pitchMultiplier = 1.12
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    /// Speak after the current line finishes (for multi-sentence sequences).
    func queue(_ text: String) {
        say(text, interrupt: false)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
