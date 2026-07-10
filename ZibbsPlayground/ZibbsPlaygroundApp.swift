import SwiftUI

@main
struct ZibbsPlaygroundApp: App {
    @StateObject private var appState = AppState()
    @ObservedObject private var library = ContentLibrary.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(library)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    // Quietly look for new content online. A no-op when
                    // offline or nothing changed; never blocks the child
                    // or surfaces errors.
                    PackSync.syncIfDue()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ContentLibrary

    var body: some View {
        ZStack {
            SpaceBackground(accent: currentAccent)
                .ignoresSafeArea()

            switch appState.screen {
            case .home:
                HomeView()
                    .transition(.opacity.combined(with: .scale(scale: 1.06)))
            case .world(let worldID):
                if let world = library.world(id: worldID) {
                    WorldMapView(world: world)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            case .level(let levelID):
                if let (world, level) = library.find(levelID: levelID) {
                    LevelHostView(world: world, level: level)
                        .id(levelID)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: appState.screen)
    }

    private var currentAccent: Color {
        switch appState.screen {
        case .home:
            return Theme.nebulaPurple
        case .world(let worldID):
            return library.world(id: worldID)?.accent ?? Theme.nebulaPurple
        case .level(let levelID):
            return library.find(levelID: levelID)?.0.accent ?? Theme.nebulaPurple
        }
    }
}
