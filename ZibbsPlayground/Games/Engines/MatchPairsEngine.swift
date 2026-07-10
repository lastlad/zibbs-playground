import SwiftUI

/// Template engine: "match the pairs". Targets sit in a row, each with an
/// empty socket beneath it; the child drags pieces from the tray into the
/// socket they belong to. Content comes entirely from a pack's
/// MatchPairsConfig.
struct MatchPairsEngine: View {
    let context: GameContext
    let config: MatchPairsConfig

    private struct PairItem: Identifiable, Equatable {
        let id = UUID()
        let pair: MatchPairsConfig.Pair
        static func == (lhs: PairItem, rhs: PairItem) -> Bool { lhs.id == rhs.id }
    }

    @State private var rounds: [[PairItem]] = []
    @State private var roundIndex = 0
    @State private var trayOrder: [PairItem] = []
    @State private var matched: Set<UUID> = []
    @State private var totalMatched = 0
    @State private var dragOffsets: [UUID: CGSize] = [:]
    @State private var draggingID: UUID?
    @State private var shakes: [UUID: Int] = [:]
    @State private var frames: [String: CGRect] = [:]
    @State private var finished = false
    @State private var entered = false

    private var round: [PairItem] {
        rounds.indices.contains(roundIndex) ? rounds[roundIndex] : []
    }

    private var spokenPrompt: String { config.spoken ?? config.prompt }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                InstructionBar(text: config.prompt, speakOnTap: spokenPrompt)
                EngineProgressDots(total: config.pairs.count, filled: totalMatched)
            }

            HStack(spacing: 44) {
                ForEach(round) { pairItem in
                    targetView(pairItem)
                }
            }
            .frame(maxHeight: .infinity)
            .scaleEffect(entered ? 1.0 : 0.8)
            .opacity(entered ? 1.0 : 0.0)

            trayView
                .zIndex(10)   // dragged pieces render above the targets
        }
        .coordinateSpace(name: "game")
        .onPreferenceChange(FramePreferenceKey.self) { frames = $0 }
        .onAppear(perform: setUp)
    }

    // MARK: Targets

    private func targetView(_ pairItem: PairItem) -> some View {
        let isMatched = matched.contains(pairItem.id)
        return VStack(spacing: 14) {
            PackVisualView(visual: pairItem.pair.target,
                           size: 138,
                           tint: isMatched ? Theme.successGreen : Theme.cosmicBlue,
                           highlighted: isMatched)

            // The socket the dragged piece snaps into.
            ZStack {
                if isMatched {
                    PackVisualView(visual: pairItem.pair.drag,
                                   size: 84,
                                   tint: Theme.successGreen,
                                   highlighted: true)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            draggingID != nil ? Theme.starYellow.opacity(0.85) : .white.opacity(0.35),
                            style: StrokeStyle(lineWidth: 3.5, dash: [8, 7])
                        )
                        .frame(width: 84, height: 84)
                }
            }
            .frame(width: 96, height: 96)
        }
        .captureFrame(id: "target-\(pairItem.id.uuidString)")
    }

    // MARK: Tray

    private var trayView: some View {
        HStack(spacing: 30) {
            ForEach(trayOrder) { pairItem in
                if !matched.contains(pairItem.id) {
                    PackVisualView(visual: pairItem.pair.drag, size: 104, tint: Theme.nebulaPurple)
                        .floating(amplitude: 3, period: 2.6,
                                  phase: Double(abs(pairItem.id.hashValue % 6)))
                        .scaleEffect(draggingID == pairItem.id ? 1.1 : 1.0)
                        .shake(times: shakes[pairItem.id] ?? 0)
                        .offset(dragOffsets[pairItem.id] ?? .zero)
                        .zIndex(draggingID == pairItem.id ? 50 : 1)
                        .gesture(dragGesture(for: pairItem))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(height: 128)
        .frame(maxWidth: .infinity)
        .gamePanel(tint: Theme.cometPink)
    }

    private func dragGesture(for pairItem: PairItem) -> some Gesture {
        DragGesture(coordinateSpace: .named("game"))
            .onChanged { value in
                guard !finished else { return }
                if draggingID != pairItem.id {
                    context.play(.pop)
                    withAnimation(.easeOut(duration: 0.2)) { draggingID = pairItem.id }
                }
                dragOffsets[pairItem.id] = value.translation
            }
            .onEnded { value in
                withAnimation(.easeOut(duration: 0.2)) { draggingID = nil }
                guard !finished else { snapBack(pairItem); return }
                drop(pairItem, at: value.location)
            }
    }

    // MARK: Game flow

    private func setUp() {
        guard rounds.isEmpty else { return }
        let perRound = config.perRound ?? 3
        let items = config.pairs.shuffled().map { PairItem(pair: $0) }
        rounds = stride(from: 0, to: items.count, by: perRound).map {
            Array(items[$0..<min($0 + perRound, items.count)])
        }
        trayOrder = round.shuffled()
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { entered = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if totalMatched == 0, !finished {
                context.say(spokenPrompt)
            }
        }
    }

    private func drop(_ pairItem: PairItem, at point: CGPoint) {
        guard let hit = round.first(where: { candidate in
            !matched.contains(candidate.id)
                && (frames["target-\(candidate.id.uuidString)"]?
                        .insetBy(dx: -22, dy: -22).contains(point) ?? false)
        }) else {
            snapBack(pairItem)
            return
        }

        if hit.id == pairItem.id {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                _ = matched.insert(pairItem.id)
                totalMatched += 1
            }
            dragOffsets[pairItem.id] = nil
            let roundComplete = matched.count == round.count
            if let success = pairItem.pair.success {
                context.play(.ding)
                context.say(success)
            } else {
                context.correct(speak: roundComplete)
            }
            if roundComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { nextRoundOrFinish() }
            }
        } else {
            withAnimation(.linear(duration: 0.4)) {
                shakes[pairItem.id, default: 0] += 1
            }
            context.tryAgain()
            snapBack(pairItem)
        }
    }

    private func nextRoundOrFinish() {
        if roundIndex + 1 < rounds.count {
            roundIndex += 1
            matched = []
            context.play(.whoosh)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                trayOrder = round.shuffled()
            }
        } else {
            finished = true
            context.play(.tada)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                context.finish()
            }
        }
    }

    private func snapBack(_ pairItem: PairItem) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
            dragOffsets[pairItem.id] = .zero
        }
    }
}
