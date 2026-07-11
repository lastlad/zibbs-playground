import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ContentLibrary
    @State private var appeared = false
    @State private var syncing = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer(minLength: 16)

                // Title
                VStack(spacing: 4) {
                    Text("ZIBB'S PLAYGROUND")
                        .font(Theme.rounded(min(60, geo.size.width * 0.055), weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.starYellow, Theme.rocketOrange],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Theme.starYellow.opacity(0.5), radius: 16)
                    Text("New worlds beam down from the stars")
                        .font(Theme.rounded(21, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 12)

                // Planets — one card per world (every world is a content
                // pack); scrolls sideways once they outgrow the screen.
                if library.worlds.isEmpty {
                    emptyState
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 36) {
                            ForEach(Array(library.worlds.enumerated()), id: \.element.id) { index, world in
                                planetCard(for: world, index: index)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .frame(minWidth: geo.size.width)   // centers when cards fit
                    }
                }

                Spacer(minLength: 12)

                // Zibb + total stars
                HStack(spacing: 24) {
                    ZibbView(mood: .excited, size: min(130, geo.size.height * 0.21))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 40)

                    HStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.starYellow)
                        Text("\(appState.totalStars) stars collected")
                            .font(Theme.rounded(24))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.white.opacity(0.10)))
                    .opacity(appeared ? 1 : 0)
                }

                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            syncButton
                .padding(.top, 18)
                .padding(.trailing, 22)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Narrator.shared.say(AppLines.shared.homeGreeting)
            }
        }
    }

    /// Checks the repo for new worlds right now instead of waiting for the
    /// next background sync. Safe to mash: extra taps while a sync is
    /// running are no-ops, and failures stay silent like every other sync.
    private var syncButton: some View {
        Button {
            guard !syncing else { return }
            SoundFX.shared.play(.whoosh)
            syncing = true
            let worldsBefore = Set(library.worlds.map(\.id))
            Task {
                await PackSync.syncNow()
                syncing = false
                let newWorlds = library.worlds.filter { !worldsBefore.contains($0.id) }
                if let world = newWorlds.first {
                    Narrator.shared.say(AppLines.shared.newWorld(world: world.name))
                }
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .rotationEffect(.degrees(syncing ? 360 : 0))
                .animation(
                    syncing
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: syncing
                )
                .padding(14)
                .background(Circle().fill(.white.opacity(0.10)))
        }
        .buttonStyle(PressBounceStyle())
        .opacity(appeared ? 1 : 0)
    }

    /// Shown only if every pack failed to load — the app stays friendly
    /// rather than blank.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🛰️").font(.system(size: 72))
            Text("New worlds are on their way!")
                .font(Theme.rounded(26))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(40)
        .gamePanel()
        .opacity(appeared ? 1 : 0)
    }

    private func planetCard(for world: World, index: Int) -> some View {
        Button {
            SoundFX.shared.play(.whoosh)
            appState.open(world: world)
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    if world.hasRing {
                        Ellipse()
                            .strokeBorder(
                                LinearGradient(colors: [Theme.starYellow.opacity(0.9), .clear],
                                               startPoint: .leading, endPoint: .trailing),
                                lineWidth: 9
                            )
                            .frame(width: 220, height: 84)
                            .rotationEffect(.degrees(-16))
                    }
                    Circle()
                        .fill(
                            RadialGradient(colors: [world.accent, world.accentSecondary],
                                           center: UnitPoint(x: 0.35, y: 0.3),
                                           startRadius: 8, endRadius: 140)
                        )
                        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 4))
                        .frame(width: 150, height: 150)
                        .shadow(color: world.accent.opacity(0.65), radius: 22)
                    Text(world.emoji)
                        .font(.system(size: 58))
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
                .floating(amplitude: 7, period: 3.0, phase: Double(index) * 1.7)

                Text(world.name)
                    .font(Theme.rounded(28))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(world.tagline)
                    .font(Theme.rounded(17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Theme.starYellow)
                    Text("\(appState.starsEarned(in: world)) / \(world.levels.count * 3)")
                        .font(Theme.rounded(20))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(22)
            .frame(width: 272)
            .gamePanel(tint: world.accent)
        }
        .buttonStyle(PressBounceStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 60)
    }
}
