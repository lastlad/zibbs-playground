import SwiftUI

/// Maps a level to its mini-game view. Every level in Zibb's Playground is
/// played by one of the data-driven template engines in Games/Engines;
/// adding a new game *type* means adding an engine here and a case to
/// TemplateConfig.
enum GameCatalog {
    @MainActor
    static func view(for level: LevelDefinition, context: GameContext) -> AnyView {
        if case .template(let template) = level.game {
            switch template {
            case .tapChoice(let config):
                return AnyView(TapChoiceEngine(context: context, config: config))
            case .sortBins(let config):
                return AnyView(SortBinsEngine(context: context, config: config))
            case .matchPairs(let config):
                return AnyView(MatchPairsEngine(context: context, config: config))
            case .countTap(let config):
                return AnyView(CountTapEngine(context: context, config: config))
            case .orderSequence(let config):
                return AnyView(SequenceEngine(context: context, config: config))
            }
        }
        return AnyView(MissingGameView())
    }
}

struct MissingGameView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("🛠️").font(.system(size: 80))
            Text("This adventure is still being built!")
                .font(Theme.rounded(28))
                .foregroundColor(.white)
        }
    }
}
