import SwiftUI

/// Hosts one mini-game: header (back, title, replay-instructions), the game
/// itself, and the celebration overlay when the game reports completion.
struct LevelHostView: View {
    @EnvironmentObject private var appState: AppState
    let world: World
    let level: LevelDefinition

    @StateObject private var context: GameContext
    @State private var showCelebration = false

    init(world: World, level: LevelDefinition) {
        self.world = world
        self.level = level
        _context = StateObject(wrappedValue: GameContext(level: level))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                GameCatalog.view(for: level, context: context)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            if showCelebration {
                CelebrationView(
                    world: world,
                    level: level,
                    stars: context.earnedStars,
                    onNext: goToNext,
                    onMap: { appState.open(world: world) }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .onAppear {
            context.onFinish = { stars in
                appState.record(stars: stars, for: level.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showCelebration = true
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Narrator.shared.say(level.intro)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            RoundIconButton(systemName: "arrow.backward", color: world.accent) {
                appState.open(world: world)
            }
            Text("\(level.emoji)  \(level.title)")
                .font(Theme.rounded(32, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            RoundIconButton(systemName: "speaker.wave.2.fill", color: world.accent) {
                context.replayIntro()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func goToNext() {
        if let next = ContentLibrary.shared.level(after: level.id) {
            appState.open(level: next)
        } else {
            appState.open(world: world)
        }
    }
}
