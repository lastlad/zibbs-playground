import SwiftUI

// MARK: - Buttons

/// Big, bouncy, glowing capsule button — the standard tappable for the app.
/// Touch targets stay comfortably large for small fingers.
struct BigButtonStyle: ButtonStyle {
    var color: Color = Theme.cosmicBlue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.rounded(30))
            .foregroundColor(.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(colors: [color, color.opacity(0.65)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 3))
                    .shadow(color: color.opacity(0.6), radius: 12, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// Round icon button (back arrow, speaker, etc.) — min 66pt target.
struct RoundIconButton: View {
    let systemName: String
    var color: Color = Theme.nebulaPurple
    let action: () -> Void

    var body: some View {
        Button {
            SoundFX.shared.play(.tap)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 66, height: 66)
                .background(
                    Circle()
                        .fill(color.opacity(0.85))
                        .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 3))
                        .shadow(color: color.opacity(0.5), radius: 8, y: 3)
                )
        }
        .buttonStyle(PressBounceStyle())
    }
}

struct PressBounceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Panels & instruction bar

/// Frosted rounded panel used to group game content.
struct GamePanel: ViewModifier {
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(tint.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 2)
                    )
            )
    }
}

extension View {
    func gamePanel(tint: Color = .white) -> some View {
        modifier(GamePanel(tint: tint))
    }
}

/// The instruction strip shown at the top of a game: a speaker icon that
/// re-narrates the line, next to large readable text (builds word recognition).
struct InstructionBar: View {
    let text: String
    var speakOnTap: String? = nil   // custom narration if different from text

    var body: some View {
        Button {
            SoundFX.shared.play(.tap)
            Narrator.shared.say(speakOnTap ?? text)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.starYellow)
                Text(text)
                    .font(Theme.rounded(26))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.white.opacity(0.12))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 2))
            )
        }
        .buttonStyle(PressBounceStyle())
    }
}

// MARK: - Stars

struct StarsView: View {
    let earned: Int
    var total: Int = 3
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: size * 0.18) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: index < earned ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(index < earned ? Theme.starYellow : .white.opacity(0.35))
                    .shadow(color: index < earned ? Theme.starYellow.opacity(0.7) : .clear,
                            radius: 5)
            }
        }
    }
}

// MARK: - Emoji tile

/// An emoji in a soft glowing bubble — the standard "object" in games.
struct EmojiTile: View {
    let emoji: String
    var size: CGFloat = 110
    var tint: Color = Theme.cosmicBlue
    var highlighted: Bool = false

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.62))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(tint.opacity(highlighted ? 0.55 : 0.25))
                    .overlay(
                        Circle().strokeBorder(
                            highlighted ? Theme.starYellow : .white.opacity(0.30),
                            lineWidth: highlighted ? 5 : 3
                        )
                    )
                    .shadow(color: highlighted ? Theme.starYellow.opacity(0.6) : tint.opacity(0.4),
                            radius: highlighted ? 14 : 8)
            )
    }
}

// MARK: - Motion effects

/// Horizontal shake for gentle "not quite" feedback.
/// Usage: keep an Int counter in @State, apply `.shake(times: wrongCount)`,
/// and increment the counter inside `withAnimation` to trigger a wiggle.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 3), y: 0)
        )
    }
}

extension View {
    func shake(times: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(times)))
    }
}

/// Gentle endless bobbing (floating in space).
struct FloatingModifier: ViewModifier {
    var amplitude: CGFloat = 8
    var period: Double = 2.4
    var phase: Double = 0

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            content
                .offset(y: amplitude * CGFloat(sin(2 * .pi * t / period + phase)))
        }
    }
}

extension View {
    func floating(amplitude: CGFloat = 8, period: Double = 2.4, phase: Double = 0) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, period: period, phase: phase))
    }
}

// MARK: - Frame reporting (for drag & drop games)

/// Games report the frames of drop targets with `.captureFrame(id:)` and read
/// them back with `.onPreferenceChange(FramePreferenceKey.self)`, using a
/// shared named coordinate space (`.coordinateSpace(name: "game")`).
struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func captureFrame(id: String, in coordinateSpace: String = "game") -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(coordinateSpace))]
                )
            }
        )
    }
}
