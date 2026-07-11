import SwiftUI

/// Template engine: "sort into bins". Two or three labeled bins sit at the
/// top; items appear in the tray in small waves and the child drags each one
/// home. Wrong bins wiggle and encourage, right bins collect the item.
/// Content comes entirely from a pack's SortBinsConfig.
struct SortBinsEngine: View {
    let context: GameContext
    let config: SortBinsConfig

    private struct TrayItem: Identifiable, Equatable {
        let id = UUID()
        let item: SortBinsConfig.Item
        static func == (lhs: TrayItem, rhs: TrayItem) -> Bool { lhs.id == rhs.id }
    }

    @State private var waves: [[TrayItem]] = []
    @State private var waveIndex = 0
    @State private var tray: [TrayItem] = []
    @State private var binContents: [[PackVisual]] = []
    @State private var dragOffsets: [UUID: CGSize] = [:]
    @State private var draggingID: UUID?
    @State private var shakes: [UUID: Int] = [:]
    @State private var frames: [String: CGRect] = [:]
    @State private var totalPlaced = 0
    @State private var finished = false
    @State private var entered = false

    private var spokenPrompt: String { config.spoken ?? config.prompt }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                InstructionBar(text: config.prompt, speakOnTap: spokenPrompt)
                EngineProgressDots(total: config.items.count, filled: totalPlaced)
            }

            HStack(spacing: 24) {
                ForEach(Array(config.bins.enumerated()), id: \.offset) { index, bin in
                    binView(index: index, bin: bin)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 8)
            .scaleEffect(entered ? 1.0 : 0.8)
            .opacity(entered ? 1.0 : 0.0)

            trayView
                .zIndex(10)   // dragged items render above the bins
        }
        .coordinateSpace(name: "game")
        .onPreferenceChange(FramePreferenceKey.self) { frames = $0 }
        .onAppear(perform: setUp)
    }

    // MARK: Bins

    private func binView(index: Int, bin: SortBinsConfig.Bin) -> some View {
        let isTarget = draggingID != nil
        return VStack(spacing: 8) {
            Text(bin.emoji)
                .font(.system(size: 54))
            Text(bin.label)
                .font(Theme.rounded(26))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 5) {
                ForEach(Array(binContents[safe: index, default: []].enumerated()), id: \.offset) { _, visual in
                    PackVisualView(visual: visual, size: 44, tint: Theme.successGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 50)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.cosmicBlue.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            isTarget ? Theme.starYellow.opacity(0.85) : .white.opacity(0.22),
                            style: StrokeStyle(lineWidth: isTarget ? 4 : 2,
                                               dash: isTarget ? [10, 8] : [])
                        )
                )
        )
        .captureFrame(id: "bin\(index)")
    }

    // MARK: Tray

    private var trayView: some View {
        HStack(spacing: 28) {
            ForEach(tray) { trayItem in
                PackVisualView(visual: trayItem.item.visual, size: 108)
                    .floating(amplitude: 3, period: 2.6,
                              phase: Double(abs(trayItem.id.hashValue % 6)))
                    .scaleEffect(draggingID == trayItem.id ? 1.1 : 1.0)
                    .shake(times: shakes[trayItem.id] ?? 0)
                    .offset(dragOffsets[trayItem.id] ?? .zero)
                    .zIndex(draggingID == trayItem.id ? 50 : 1)
                    .gesture(dragGesture(for: trayItem))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 132)
        .frame(maxWidth: .infinity)
        .gamePanel(tint: Theme.nebulaPurple)
    }

    private func dragGesture(for trayItem: TrayItem) -> some Gesture {
        DragGesture(coordinateSpace: .named("game"))
            .onChanged { value in
                guard !finished else { return }
                if draggingID != trayItem.id {
                    context.play(.pop)
                    withAnimation(.easeOut(duration: 0.2)) { draggingID = trayItem.id }
                }
                dragOffsets[trayItem.id] = value.translation
            }
            .onEnded { value in
                withAnimation(.easeOut(duration: 0.2)) { draggingID = nil }
                guard !finished else { snapBack(trayItem); return }
                drop(trayItem, at: value.location)
            }
    }

    // MARK: Game flow

    private func setUp() {
        guard waves.isEmpty else { return }
        binContents = Array(repeating: [], count: config.bins.count)
        let perWave = config.perWave ?? 4
        let shuffled = config.items.shuffled().map { TrayItem(item: $0) }
        waves = stride(from: 0, to: shuffled.count, by: perWave).map {
            Array(shuffled[$0..<min($0 + perWave, shuffled.count)])
        }
        tray = waves[0]
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { entered = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if totalPlaced == 0, !finished {
                context.say(spokenPrompt)
            }
        }
    }

    private func drop(_ trayItem: TrayItem, at point: CGPoint) {
        guard let binIndex = config.bins.indices.first(where: { index in
            frames["bin\(index)"]?.insetBy(dx: -25, dy: -25).contains(point) ?? false
        }) else {
            snapBack(trayItem)
            return
        }

        if binIndex == trayItem.item.bin {
            context.correct(speak: false)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                tray.removeAll { $0.id == trayItem.id }
                binContents[binIndex].append(trayItem.item.visual)
                totalPlaced += 1
            }
            dragOffsets[trayItem.id] = nil
            if let name = trayItem.item.name {
                context.say(name)
            }
            if tray.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { nextWaveOrFinish() }
            }
        } else {
            withAnimation(.linear(duration: 0.4)) {
                shakes[trayItem.id, default: 0] += 1
            }
            context.tryAgain()
            snapBack(trayItem)
        }
    }

    private func nextWaveOrFinish() {
        if waveIndex + 1 < waves.count {
            waveIndex += 1
            context.play(.whoosh)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                tray = waves[waveIndex]
            }
        } else {
            finished = true
            context.play(.tada)
            context.say(AppLines.shared.sortComplete)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                context.finish()
            }
        }
    }

    private func snapBack(_ trayItem: TrayItem) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
            dragOffsets[trayItem.id] = .zero
        }
    }
}

private extension Array {
    subscript(safe index: Int, default defaultValue: @autoclosure () -> Element) -> Element {
        indices.contains(index) ? self[index] : defaultValue()
    }
}
