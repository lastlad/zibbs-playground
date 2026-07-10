import SwiftUI

/// Template engine: "put them in order". A rail of empty numbered slots runs
/// across the top; shuffled tiles wait below, and the child taps whichever
/// comes next — it pops up into its slot. Content comes entirely from a
/// pack's SequenceConfig.
struct SequenceEngine: View {
    let context: GameContext
    let config: SequenceConfig

    @State private var roundIndex = 0
    @State private var placedCount = 0
    @State private var trayOrder: [Int] = []
    @State private var shakes: [Int: Int] = [:]
    @State private var roundDone = false
    @State private var entered = false

    private var round: SequenceConfig.Round? {
        config.rounds.indices.contains(roundIndex) ? config.rounds[roundIndex] : nil
    }

    private var spokenPrompt: String {
        round.map { $0.spoken ?? $0.prompt } ?? ""
    }

    var body: some View {
        VStack(spacing: 12) {
            InstructionBar(text: round?.prompt ?? "", speakOnTap: spokenPrompt)
            EngineProgressDots(total: config.rounds.count,
                               filled: roundIndex + (roundDone ? 1 : 0))

            if let round {
                Spacer(minLength: 0)
                slotRail(for: round)
                Spacer(minLength: 0)
                trayView(for: round)
                    .padding(.bottom, 6)
            }
        }
        .scaleEffect(entered ? 1.0 : 0.8)
        .opacity(entered ? 1.0 : 0.0)
        .onAppear(perform: setUp)
    }

    // MARK: Slot rail

    private func slotRail(for round: SequenceConfig.Round) -> some View {
        let slotSize: CGFloat = round.items.count <= 4 ? 128 : 104
        return HStack(spacing: 10) {
            ForEach(round.items.indices, id: \.self) { index in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                }
                ZStack {
                    if index < placedCount {
                        PackVisualView(visual: round.items[index],
                                       size: slotSize,
                                       tint: Theme.successGreen,
                                       highlighted: index == placedCount - 1)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: slotSize * 0.2, style: .continuous)
                            .strokeBorder(
                                index == placedCount ? Theme.starYellow.opacity(0.9) : .white.opacity(0.3),
                                style: StrokeStyle(lineWidth: 3.5, dash: [9, 8])
                            )
                            .frame(width: slotSize, height: slotSize)
                            .overlay(
                                Text("\(index + 1)")
                                    .font(Theme.rounded(slotSize * 0.32, weight: .heavy))
                                    .foregroundColor(.white.opacity(0.35))
                            )
                    }
                }
            }
            if roundDone {
                ZibbView(mood: .celebrating, size: 92)
                    .padding(.leading, 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: placedCount)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: roundDone)
    }

    // MARK: Tray

    private func trayView(for round: SequenceConfig.Round) -> some View {
        let tileSize: CGFloat = round.items.count <= 4 ? 118 : 100
        return HStack(spacing: 26) {
            ForEach(trayOrder, id: \.self) { itemIndex in
                if itemIndex >= placedCount {
                    Button {
                        tapped(itemIndex, in: round)
                    } label: {
                        PackVisualView(visual: round.items[itemIndex],
                                       size: tileSize,
                                       tint: Theme.nebulaPurple)
                    }
                    .buttonStyle(PressBounceStyle())
                    .shake(times: shakes[itemIndex] ?? 0)
                    .floating(amplitude: 4, period: 2.7, phase: Double(itemIndex) * 1.5)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(height: 134)
        .frame(maxWidth: .infinity)
        .gamePanel(tint: Theme.cosmicBlue)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: placedCount)
    }

    // MARK: Game flow

    private func setUp() {
        guard trayOrder.isEmpty else { return }
        resetRound()
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { entered = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if roundIndex == 0, placedCount == 0 {
                context.say(spokenPrompt)
            }
        }
    }

    private func resetRound() {
        guard let round else { return }
        placedCount = 0
        roundDone = false
        shakes = [:]
        // Shuffle until the tray doesn't accidentally show the solved order.
        var order = Array(round.items.indices)
        repeat { order.shuffle() } while order == Array(round.items.indices) && order.count > 1
        trayOrder = order
    }

    private func tapped(_ itemIndex: Int, in round: SequenceConfig.Round) {
        guard !roundDone else { return }
        if itemIndex == placedCount {
            context.play(.pop)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                placedCount += 1
            }
            if let names = round.names, names.indices.contains(itemIndex) {
                context.say(names[itemIndex])
            }
            if placedCount == round.items.count {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { roundDone = true }
                context.play(.star)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    context.correct(round.success)
                }
                if roundIndex == config.rounds.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                        context.finish()
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        advanceRound()
                    }
                }
            }
        } else {
            withAnimation(.linear(duration: 0.4)) {
                shakes[itemIndex, default: 0] += 1
            }
            context.tryAgain("Which one comes next? Look at the empty spot!")
        }
    }

    private func advanceRound() {
        context.play(.whoosh)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            roundIndex += 1
        }
        resetRound()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            context.say(spokenPrompt)
        }
    }
}
