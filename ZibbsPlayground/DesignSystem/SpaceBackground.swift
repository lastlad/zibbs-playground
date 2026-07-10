import SwiftUI

/// Animated deep-space backdrop: nebula gradient tinted by the current world's
/// accent color, plus a field of gently twinkling stars drawn in one Canvas.
struct SpaceBackground: View {
    var accent: Color = Theme.nebulaPurple

    private static let stars: [Star] = (0..<90).map { _ in Star() }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.deepSpace, Theme.midSpace, Theme.deepSpace],
                startPoint: .top, endPoint: .bottom
            )

            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: UnitPoint(x: 0.85, y: 0.1),
                startRadius: 10, endRadius: 600
            )
            RadialGradient(
                colors: [Theme.cosmicBlue.opacity(0.18), .clear],
                center: UnitPoint(x: 0.1, y: 0.9),
                startRadius: 10, endRadius: 500
            )

            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                Canvas { canvasContext, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for star in Self.stars {
                        let twinkle = 0.55 + 0.45 * sin(time * star.speed + star.phase)
                        let rect = CGRect(
                            x: star.x * size.width,
                            y: star.y * size.height,
                            width: star.size, height: star.size
                        )
                        canvasContext.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(0.85 * twinkle))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private struct Star {
        let x = Double.random(in: 0...1)
        let y = Double.random(in: 0...1)
        let size = Double.random(in: 1.5...4.0)
        let speed = Double.random(in: 0.6...2.2)
        let phase = Double.random(in: 0...(2 * .pi))
    }
}
