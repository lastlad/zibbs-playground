import SwiftUI

/// Full-screen celebration after finishing a level: confetti, stars that pop
/// in one by one, Zibb celebrating, and big Next / Map buttons.
struct CelebrationView: View {
    let world: World
    let level: LevelDefinition
    let stars: Int
    let onNext: () -> Void
    let onMap: () -> Void

    @State private var visibleStars = 0
    @State private var showButtons = false

    private var isLastLevel: Bool {
        ContentLibrary.shared.level(after: level.id) == nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            ConfettiView(colors: [Theme.starYellow, Theme.cometPink, Theme.iceBlue,
                                  Theme.alienGreen, Theme.rocketOrange])
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 26) {
                Text("YOU DID IT!")
                    .font(Theme.rounded(56, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.starYellow, Theme.rocketOrange],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Theme.starYellow.opacity(0.6), radius: 18)

                HStack(spacing: 22) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 66, weight: .bold))
                            .foregroundColor(index < stars ? Theme.starYellow : .white.opacity(0.25))
                            .shadow(color: index < stars ? Theme.starYellow.opacity(0.8) : .clear,
                                    radius: 12)
                            .scaleEffect(index < visibleStars ? 1 : 0.01)
                            .animation(.spring(response: 0.45, dampingFraction: 0.5),
                                       value: visibleStars)
                    }
                }

                ZibbView(mood: .celebrating, size: 150)

                Text(level.concept)
                    .font(Theme.rounded(24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 26) {
                    Button {
                        SoundFX.shared.play(.whoosh)
                        onMap()
                    } label: {
                        Label("Map", systemImage: "map.fill")
                    }
                    .buttonStyle(BigButtonStyle(color: world.accentSecondary))

                    Button {
                        SoundFX.shared.play(.whoosh)
                        onNext()
                    } label: {
                        Label(isLastLevel ? "Finish" : "Next", systemImage:
                                isLastLevel ? "flag.checkered" : "arrow.forward")
                    }
                    .buttonStyle(BigButtonStyle(color: world.accent))
                }
                .opacity(showButtons ? 1 : 0)
                .offset(y: showButtons ? 0 : 30)
            }
        }
        .onAppear {
            for index in 1...stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 * Double(index)) {
                    SoundFX.shared.play(.star)
                    visibleStars = index
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Narrator.shared.say(celebrationLine)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showButtons = true
                }
            }
        }
    }

    private var celebrationLine: String {
        if isLastLevel {
            return AppLines.shared.celebrationFinale(world: world.name)
        }
        return AppLines.shared.celebration(stars: stars)
    }
}

/// Lightweight confetti: fixed particle set falling and spinning, drawn in a
/// single Canvas driven by TimelineView.
struct ConfettiView: View {
    let colors: [Color]
    private static let particles: [Particle] = (0..<70).map { _ in Particle() }
    @State private var startTime = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { canvasContext, size in
                let t = timeline.date.timeIntervalSince(startTime)
                for particle in Self.particles {
                    let progress = (t * particle.speed + particle.delay)
                        .truncatingRemainder(dividingBy: 1.3) / 1.3
                    let x = particle.x * size.width
                        + 30 * sin(t * 2 + particle.phase)
                    let y = progress * (size.height + 60) - 30
                    let rect = CGRect(x: 0, y: 0, width: particle.width, height: particle.height)
                    var copy = canvasContext
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(t * particle.spin + particle.phase))
                    copy.fill(Path(roundedRect: rect, cornerRadius: 2),
                              with: .color(colors[particle.colorIndex % colors.count]))
                }
            }
        }
    }

    private struct Particle {
        let x = Double.random(in: 0...1)
        let width = Double.random(in: 8...16)
        let height = Double.random(in: 5...10)
        let speed = Double.random(in: 0.25...0.55)
        let delay = Double.random(in: 0...1.3)
        let spin = Double.random(in: 1.5...5.0)
        let phase = Double.random(in: 0...(2 * .pi))
        let colorIndex = Int.random(in: 0...4)
    }
}
