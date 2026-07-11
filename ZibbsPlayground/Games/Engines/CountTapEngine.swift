import SwiftUI

/// Template engine: "tap and count". Each round scatters a friendly group of
/// emoji; the child taps each one once while Zibb counts out loud, and a big
/// numeral ticks up alongside — hearing "three" while seeing "3". Content
/// comes entirely from a pack's CountTapConfig.
struct CountTapEngine: View {
    let context: GameContext
    let config: CountTapConfig

    @State private var roundIndex = 0
    @State private var tapped: Set<Int> = []
    @State private var roundDone = false
    @State private var entered = false

    private var round: CountTapConfig.Round? {
        config.rounds.indices.contains(roundIndex) ? config.rounds[roundIndex] : nil
    }

    private var spokenPrompt: String {
        round.map { $0.spoken ?? $0.prompt } ?? ""
    }

    var body: some View {
        VStack(spacing: 14) {
            InstructionBar(text: round?.prompt ?? "", speakOnTap: spokenPrompt)
            EngineProgressDots(total: config.rounds.count,
                               filled: roundIndex + (roundDone ? 1 : 0))

            if let round {
                HStack(spacing: 30) {
                    itemGrid(for: round)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    counterBadge
                }
                .padding(.horizontal, 10)
            }
        }
        .scaleEffect(entered ? 1.0 : 0.8)
        .opacity(entered ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { entered = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if roundIndex == 0, tapped.isEmpty {
                    context.say(spokenPrompt)
                }
            }
        }
    }

    // MARK: Pieces

    /// One row up to five items, two balanced rows after that — tidy enough
    /// to count, jittered enough to feel alive.
    private func itemGrid(for round: CountTapConfig.Round) -> some View {
        let count = round.count
        let topCount = count <= 5 ? count : (count + 1) / 2
        let rows: [[Int]] = count <= 5
            ? [Array(0..<count)]
            : [Array(0..<topCount), Array(topCount..<count)]
        let size: CGFloat = count <= 5 ? 130 : 110

        return VStack(spacing: 26) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 30) {
                    ForEach(row, id: \.self) { index in
                        itemTile(index: index, emoji: round.emoji, size: size)
                    }
                }
            }
        }
    }

    private func itemTile(index: Int, emoji: String, size: CGFloat) -> some View {
        let isTapped = tapped.contains(index)
        return Button {
            tap(index)
        } label: {
            EmojiTile(emoji: emoji,
                      size: size,
                      tint: isTapped ? Theme.successGreen : Theme.cosmicBlue,
                      highlighted: isTapped)
                .overlay(alignment: .topTrailing) {
                    if isTapped {
                        Text("\(orderOfTap(index))")
                            .font(Theme.rounded(size * 0.22, weight: .heavy))
                            .foregroundColor(Theme.deepSpace)
                            .frame(width: size * 0.34, height: size * 0.34)
                            .background(Circle().fill(Theme.starYellow))
                            .offset(x: size * 0.06, y: -size * 0.06)
                            .transition(.scale)
                    }
                }
        }
        .buttonStyle(PressBounceStyle())
        .scaleEffect(isTapped ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isTapped)
        .floating(amplitude: isTapped ? 0 : 5, period: 2.8, phase: Double(index) * 1.3)
    }

    /// The big numeral that ticks up with every tap.
    private var counterBadge: some View {
        VStack(spacing: 8) {
            Text("\(tapped.count)")
                .font(Theme.rounded(96, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 150, height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Theme.nebulaPurple.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 3)
                        )
                        .shadow(color: Theme.nebulaPurple.opacity(0.6), radius: 10)
                )
                .scaleEffect(roundDone ? 1.12 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: tapped.count)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: roundDone)
            if roundDone {
                ZibbView(mood: .celebrating, size: 90)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 170)
    }

    // MARK: Game flow

    /// Taps keep their order so each tile wears the number it was counted as.
    @State private var tapOrder: [Int] = []

    private func orderOfTap(_ index: Int) -> Int {
        (tapOrder.firstIndex(of: index) ?? 0) + 1
    }

    private func tap(_ index: Int) {
        guard let round, !roundDone, !tapped.contains(index) else { return }
        context.play(.pop)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            tapped.insert(index)
            tapOrder.append(index)
        }
        let number = tapped.count
        context.say(SpokenNumber.word(number).capitalized + "!")

        guard number == round.count else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { roundDone = true }
        context.play(.star)
        let word = SpokenNumber.word(round.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            context.say(round.success ?? AppLines.shared.countSuccess(word: word))
        }
        if roundIndex == config.rounds.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                context.finish()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                advanceRound()
            }
        }
    }

    private func advanceRound() {
        context.play(.whoosh)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            roundIndex += 1
            tapped = []
            tapOrder = []
            roundDone = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            context.say(spokenPrompt)
        }
    }
}
