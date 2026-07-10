import SwiftUI

/// Template engine: "tap the right one". Each round shows a question and
/// 2–4 big tappable options; wrong taps wiggle and encourage, the right tap
/// bounces, praises, and moves on. Content comes entirely from a pack's
/// TapChoiceConfig.
struct TapChoiceEngine: View {
    let context: GameContext
    let config: TapChoiceConfig

    @State private var roundIndex = 0
    @State private var orders: [[Int]] = []       // per round: display order of option indices
    @State private var solvedPosition: Int? = nil
    @State private var shakes: [Int] = [0, 0, 0, 0]
    @State private var tilesShown = false

    private var round: TapChoiceConfig.Round? {
        config.rounds.indices.contains(roundIndex) ? config.rounds[roundIndex] : nil
    }

    private var order: [Int] {
        orders.indices.contains(roundIndex) ? orders[roundIndex] : []
    }

    private var spokenQuestion: String {
        round.map { $0.spoken ?? $0.question } ?? ""
    }

    private func tileSize(optionCount: Int) -> CGFloat {
        switch optionCount {
        case 2: return 190
        case 3: return 170
        default: return 148
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            InstructionBar(text: round?.question ?? "", speakOnTap: spokenQuestion)
            EngineProgressDots(total: config.rounds.count,
                               filled: roundIndex + (solvedPosition != nil ? 1 : 0))

            Spacer(minLength: 0)

            if let round {
                HStack(spacing: 40) {
                    ForEach(Array(order.enumerated()), id: \.offset) { position, optionIndex in
                        optionTile(position: position,
                                   optionIndex: optionIndex,
                                   visual: round.options[optionIndex],
                                   size: tileSize(optionCount: round.options.count))
                    }
                }
                .padding(.vertical, 10)
            }

            Spacer(minLength: 0)

            Button {
                context.play(.tap)
                context.say(spokenQuestion)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.3.fill")
                    Text("Hear it again")
                }
            }
            .buttonStyle(BigButtonStyle(color: Theme.nebulaPurple))
            .padding(.bottom, 8)
        }
        .onAppear(perform: setUp)
    }

    private func optionTile(position: Int, optionIndex: Int, visual: PackVisual, size: CGFloat) -> some View {
        Button {
            tapped(position: position, optionIndex: optionIndex)
        } label: {
            PackVisualView(
                visual: visual,
                size: size,
                tint: position == solvedPosition ? Theme.successGreen : Theme.cosmicBlue,
                highlighted: position == solvedPosition
            )
        }
        .buttonStyle(PressBounceStyle())
        .scaleEffect(position == solvedPosition ? 1.16 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.45), value: solvedPosition)
        .shake(times: shakes[position])
        .floating(amplitude: 6, period: 2.6, phase: Double(position) * 1.7)
        .scaleEffect(tilesShown ? 1 : 0.2)
        .opacity(tilesShown ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.6).delay(Double(position) * 0.09),
            value: tilesShown
        )
    }

    // MARK: Game flow

    private func setUp() {
        guard orders.isEmpty else { return }
        let shuffle = config.shuffleOptions ?? true
        orders = config.rounds.map { round in
            let indices = Array(round.options.indices)
            return shuffle ? indices.shuffled() : indices
        }
        withAnimation { tilesShown = true }
        // Let the host finish narrating the level intro before the question.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if roundIndex == 0, solvedPosition == nil {
                context.say(spokenQuestion)
            }
        }
    }

    private func tapped(position: Int, optionIndex: Int) {
        guard let round, solvedPosition == nil else { return }
        if optionIndex == round.answer {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) {
                solvedPosition = position
            }
            context.correct(round.success)
            if roundIndex == config.rounds.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    context.finish()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    advanceRound()
                }
            }
        } else {
            context.tryAgain(round.hint)
            withAnimation(.linear(duration: 0.4)) {
                shakes[position] += 1
            }
        }
    }

    private func advanceRound() {
        withAnimation(.easeIn(duration: 0.22)) { tilesShown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            roundIndex += 1
            solvedPosition = nil
            shakes = [0, 0, 0, 0]
            context.play(.whoosh)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                tilesShown = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                context.say(spokenQuestion)
            }
        }
    }
}
