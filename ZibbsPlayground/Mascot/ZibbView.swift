import SwiftUI

/// Zibb — the friendly alien guide. Drawn entirely with SwiftUI shapes:
/// squishy green body, two big eyes that blink and look around, one glowing
/// antenna, stubby arms and feet. Moods change the eyes, mouth, and arms.
struct ZibbView: View {
    enum Mood {
        case happy        // default: soft smile, arms relaxed
        case excited      // open mouth, arms halfway up, faster bob
        case thinking     // pupils up, small "o" mouth
        case celebrating  // arms up, big open smile, bouncing
    }

    var mood: Mood = .happy
    var size: CGFloat = 160

    @State private var blinking = false
    @State private var bouncePhase = false

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [Theme.alienGreen, Color(red: 0.16, green: 0.62, blue: 0.42)],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            antenna
            bodyShape
            face
            arms
            feet
        }
        .frame(width: size, height: size * 1.25)
        .scaleEffect(y: bouncePhase && mood == .celebrating ? 1.06 : 1.0, anchor: .bottom)
        .floating(amplitude: mood == .excited || mood == .celebrating ? 6 : 4,
                  period: mood == .excited || mood == .celebrating ? 1.2 : 2.6)
        .onAppear {
            startBlinking()
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                bouncePhase = true
            }
        }
    }

    // MARK: Parts

    private var bodyShape: some View {
        Ellipse()
            .fill(bodyGradient)
            .overlay(
                // lighter belly
                Ellipse()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: size * 0.52, height: size * 0.45)
                    .offset(y: size * 0.28)
            )
            .overlay(Ellipse().strokeBorder(.white.opacity(0.25), lineWidth: 2.5))
            .frame(width: size * 0.92, height: size * 1.02)
            .shadow(color: Theme.alienGreen.opacity(0.45), radius: 14, y: 4)
            .offset(y: size * 0.06)
    }

    private var antenna: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Theme.starYellow)
                .frame(width: size * 0.14, height: size * 0.14)
                .shadow(color: Theme.starYellow.opacity(0.9), radius: 8)
            Rectangle()
                .fill(Theme.alienGreen)
                .frame(width: size * 0.035, height: size * 0.22)
        }
        .offset(y: -size * 0.52)
    }

    private var face: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.12) {
                eye
                eye
            }
            mouth
        }
        .offset(y: -size * 0.10)
    }

    private var eye: some View {
        ZStack {
            Ellipse()
                .fill(.white)
                .frame(width: size * 0.24, height: size * 0.26)
            Circle()
                .fill(Color(red: 0.08, green: 0.10, blue: 0.20))
                .frame(width: size * 0.115, height: size * 0.115)
                .offset(pupilOffset)
            Circle()
                .fill(.white)
                .frame(width: size * 0.04, height: size * 0.04)
                .offset(x: size * 0.02 + pupilOffset.width, y: -size * 0.025 + pupilOffset.height)
        }
        .scaleEffect(y: blinking ? 0.08 : 1.0)
        .animation(.easeInOut(duration: 0.09), value: blinking)
    }

    private var pupilOffset: CGSize {
        switch mood {
        case .thinking: return CGSize(width: size * 0.02, height: -size * 0.05)
        case .excited, .celebrating: return CGSize(width: 0, height: size * 0.01)
        case .happy: return .zero
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .happy:
            SmileArc()
                .stroke(Color(red: 0.08, green: 0.10, blue: 0.20),
                        style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .frame(width: size * 0.26, height: size * 0.12)
        case .thinking:
            Circle()
                .fill(Color(red: 0.08, green: 0.10, blue: 0.20))
                .frame(width: size * 0.07, height: size * 0.07)
        case .excited, .celebrating:
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.20))
                Ellipse()
                    .fill(Theme.cometPink.opacity(0.8))
                    .frame(width: size * 0.12, height: size * 0.05)
                    .offset(y: size * 0.045)
            }
            .frame(width: size * 0.22, height: size * 0.16)
        }
    }

    private var arms: some View {
        let raised = mood == .celebrating
        let halfway = mood == .excited
        let armAngle: Double = raised ? -55 : (halfway ? -20 : 18)
        return HStack {
            Capsule()
                .fill(bodyGradient)
                .frame(width: size * 0.30, height: size * 0.10)
                .rotationEffect(.degrees(-armAngle), anchor: .trailing)
                .offset(x: size * 0.10)
            Spacer()
            Capsule()
                .fill(bodyGradient)
                .frame(width: size * 0.30, height: size * 0.10)
                .rotationEffect(.degrees(armAngle), anchor: .leading)
                .offset(x: -size * 0.10)
        }
        .frame(width: size * 1.28)
        .offset(y: raised || halfway ? -size * 0.05 : size * 0.14)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: armAngle)
    }

    private var feet: some View {
        HStack(spacing: size * 0.18) {
            Ellipse()
                .fill(Color(red: 0.16, green: 0.62, blue: 0.42))
                .frame(width: size * 0.22, height: size * 0.11)
            Ellipse()
                .fill(Color(red: 0.16, green: 0.62, blue: 0.42))
                .frame(width: size * 0.22, height: size * 0.11)
        }
        .offset(y: size * 0.58)
    }

    private func startBlinking() {
        // Blink every few seconds, forever, without a Timer publisher.
        func scheduleNext() {
            let wait = Double.random(in: 2.2...4.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                blinking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                    blinking = false
                    scheduleNext()
                }
            }
        }
        scheduleNext()
    }
}

private struct SmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.6)
        )
        return path
    }
}
