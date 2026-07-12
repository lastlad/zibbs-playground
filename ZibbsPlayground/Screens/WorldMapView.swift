import SwiftUI

/// The journey map for one world: a winding dashed path across the screen
/// with a glowing node per level. Locked levels are dim; the next level
/// pulses to invite a tap.
struct WorldMapView: View {
    @EnvironmentObject private var appState: AppState
    let world: World

    /// Hand-tuned S-curve for the classic 10-level worlds.
    private static let classicPoints: [CGPoint] = [
        CGPoint(x: 0.09, y: 0.78), CGPoint(x: 0.19, y: 0.52), CGPoint(x: 0.28, y: 0.76),
        CGPoint(x: 0.37, y: 0.46), CGPoint(x: 0.47, y: 0.70), CGPoint(x: 0.56, y: 0.42),
        CGPoint(x: 0.66, y: 0.68), CGPoint(x: 0.75, y: 0.40), CGPoint(x: 0.85, y: 0.62),
        CGPoint(x: 0.92, y: 0.34),
    ]

    /// Node positions for any level count (pack worlds pick their own size):
    /// an evenly spaced zigzag that drifts gently upward, matching the feel
    /// of the hand-tuned path.
    private static func nodePoints(for count: Int) -> [CGPoint] {
        if count == classicPoints.count { return classicPoints }
        guard count > 1 else { return [CGPoint(x: 0.5, y: 0.58)] }
        return (0..<count).map { index in
            let t = CGFloat(index) / CGFloat(count - 1)
            let x = 0.09 + t * 0.83
            let y: CGFloat = (index.isMultiple(of: 2) ? 0.76 : 0.50) - t * 0.12
            return CGPoint(x: x, y: y)
        }
    }

    private var nodePoints: [CGPoint] { Self.nodePoints(for: world.levels.count) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                pathLine(in: geo.size)

                ForEach(Array(world.levels.enumerated()), id: \.element.id) { index, level in
                    let point = nodePoints[min(index, nodePoints.count - 1)]
                    levelNode(level, index: index)
                        .position(x: point.x * geo.size.width, y: point.y * geo.size.height)
                }

                // Zibb hangs out near the start of the path.
                ZibbView(mood: .happy, size: 110)
                    .position(x: 0.075 * geo.size.width, y: 0.38 * geo.size.height)
                    .allowsHitTesting(false)

                // Header
                VStack {
                    HStack(spacing: 18) {
                        RoundIconButton(systemName: "house.fill", color: world.accent) {
                            appState.goHome()
                        }
                        Text("\(world.emoji)  \(world.name)")
                            .font(Theme.rounded(38, weight: .heavy))
                            .foregroundColor(.white)
                            .shadow(color: world.accent.opacity(0.8), radius: 10)
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Theme.starYellow)
                            Text("\(appState.starsEarned(in: world))")
                                .font(Theme.rounded(28))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.12)))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    Spacer()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Narrator.shared.say(AppLines.shared.mapWelcome(world: world.name))
            }
        }
    }

    private func pathLine(in size: CGSize) -> some View {
        Path { path in
            let points = nodePoints.map {
                CGPoint(x: $0.x * size.width, y: $0.y * size.height)
            }
            guard let first = points.first else { return }
            path.move(to: first)
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
                path.addQuadCurve(to: mid,
                                  control: CGPoint(x: previous.x, y: (previous.y + mid.y) / 2))
                path.addQuadCurve(to: current,
                                  control: CGPoint(x: current.x, y: (current.y + mid.y) / 2))
            }
        }
        .stroke(
            world.accent.opacity(0.55),
            style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [2, 18])
        )
        .shadow(color: world.accent.opacity(0.4), radius: 6)
    }

    private func levelNode(_ level: LevelDefinition, index: Int) -> some View {
        let unlocked = appState.isUnlocked(level, in: world)
        let stars = appState.stars(for: level.id)
        let isNext = unlocked && stars == 0

        return Button {
            if unlocked {
                SoundFX.shared.play(.pop)
                appState.open(level: level)
            } else {
                SoundFX.shared.play(.oops)
                Narrator.shared.say(AppLines.shared.levelLocked)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            unlocked
                            ? AnyShapeStyle(
                                LinearGradient(colors: [world.accent, world.accentSecondary],
                                               startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.white.opacity(0.10))
                        )
                        .overlay(
                            Circle().strokeBorder(
                                unlocked ? Color.white.opacity(0.6) : Color.white.opacity(0.15),
                                lineWidth: 4
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: unlocked ? world.accent.opacity(0.8) : .clear, radius: 12)

                    if unlocked {
                        Text(level.emoji)
                            .font(.system(size: 46))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // number badge
                    Text("\(index + 1)")
                        .font(Theme.rounded(19, weight: .heavy))
                        .foregroundColor(unlocked ? Theme.deepSpace : .white.opacity(0.5))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(unlocked ? Theme.starYellow : Color.white.opacity(0.15))
                        )
                        .offset(x: 36, y: -36)
                }
                .modifier(PulseIfNext(active: isNext))

                Text(level.title)
                    .font(Theme.rounded(17))
                    .foregroundColor(.white.opacity(unlocked ? 0.95 : 0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 130)

                StarsView(earned: stars, size: 15)
                    .opacity(unlocked ? 1 : 0.25)
            }
        }
        .buttonStyle(PressBounceStyle())
    }
}
