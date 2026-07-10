import AVFoundation

/// All sound effects are synthesized in code at launch (no audio assets, fully
/// offline, keeps the app tiny). Buffers are pre-rendered once and played
/// through a small pool of player nodes so overlapping taps never cut out.
final class SoundFX {
    static let shared = SoundFX()

    enum Effect: CaseIterable {
        case tap      // soft click for any button
        case pop      // picking something up / placing
        case ding     // correct answer
        case oops     // gentle "not quite" (never harsh)
        case whoosh   // transitions, things flying
        case boing    // bouncy / silly moments
        case star     // collecting a star
        case tada     // level complete fanfare
        case launch   // rocket rumble & liftoff
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)

    private init() {
        guard let format else { return }
        for _ in 0..<5 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.9
        renderAllEffects()
        engine.prepare()
        try? engine.start()
    }

    func play(_ effect: Effect) {
        guard let buffer = buffers[effect], !players.isEmpty else { return }
        if !engine.isRunning {
            try? engine.start()
            guard engine.isRunning else { return }
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    // MARK: - Synthesis

    private func renderAllEffects() {
        buffers[.tap] = render(duration: 0.07) { t in
            self.sine(950, t) * self.decay(t, rate: 60) * 0.35
        }
        buffers[.pop] = render(duration: 0.10) { t in
            let freq = 420 + 700 * (t / 0.10)          // quick upward chirp
            return self.sine(freq, t) * self.decay(t, rate: 35) * 0.4
        }
        buffers[.ding] = render(duration: 0.45) { t in
            let a = self.sine(1318.5, t) * 0.5          // E6 + sparkle harmonic
            let b = self.sine(2637.0, t) * 0.18
            return (a + b) * self.decay(t, rate: 9) * 0.6
        }
        buffers[.oops] = render(duration: 0.32) { t in
            let freq: Double = t < 0.15 ? 340 : 285     // soft two-note "hmm"
            let gate = (t < 0.13 || t > 0.17) ? 1.0 : 0.0
            return self.sine(freq, t) * Float(gate) * self.decay(t, rate: 6) * 0.25
        }
        buffers[.whoosh] = render(duration: 0.45) { t in
            let bell = sin(.pi * t / 0.45)              // noise swell shaped like a gust
            return self.noise() * Float(bell * bell) * 0.28
        }
        buffers[.boing] = render(duration: 0.30) { t in
            let freq = 180 - 90 * (t / 0.30) + 22 * sin(2 * .pi * 24 * t)
            return self.sine(freq, t) * self.decay(t, rate: 10) * 0.45
        }
        buffers[.star] = render(duration: 0.34) { t in
            // fast rising three-note twinkle: A5 C#6 E6
            let freq: Double = t < 0.09 ? 880 : (t < 0.18 ? 1108.7 : 1318.5)
            let local = t < 0.09 ? t : (t < 0.18 ? t - 0.09 : t - 0.18)
            return self.sine(freq, t) * self.decay(local, rate: 16) * 0.5
        }
        buffers[.tada] = render(duration: 1.0) { t in
            // C major fanfare: C5 E5 G5 then a held C6 chord
            var sample: Float = 0
            if t < 0.12 { sample = self.sine(523.25, t) * self.decay(t, rate: 12) }
            else if t < 0.24 { sample = self.sine(659.25, t) * self.decay(t - 0.12, rate: 12) }
            else if t < 0.36 { sample = self.sine(783.99, t) * self.decay(t - 0.24, rate: 12) }
            else {
                let local = t - 0.36
                let chord = self.sine(1046.5, t) * 0.5 + self.sine(783.99, t) * 0.3 + self.sine(659.25, t) * 0.25
                sample = chord * self.decay(local, rate: 4)
            }
            return sample * 0.55
        }
        buffers[.launch] = render(duration: 1.6) { t in
            let rumble = self.noise() * self.sine(40 + 18 * sin(2 * .pi * 7 * t), t) * 0.6
            let rise = self.sine(120 + 500 * (t / 1.6), t) * 0.22
            let fade = Float(max(0, 1.0 - t / 1.6))
            return (rumble + rise) * fade * 0.6
        }
    }

    private func render(duration: Double, _ sample: @escaping (Double) -> Float) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let attack = Int(0.004 * sampleRate)
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var value = sample(t)
            if frame < attack {                          // tiny fade-in kills clicks
                value *= Float(frame) / Float(attack)
            }
            channel[frame] = max(-1, min(1, value))
        }
        return buffer
    }

    private func sine(_ frequency: Double, _ t: Double) -> Float {
        Float(sin(2.0 * .pi * frequency * t))
    }

    private func decay(_ t: Double, rate: Double) -> Float {
        Float(exp(-rate * t))
    }

    private func noise() -> Float {
        Float.random(in: -1...1)
    }
}
