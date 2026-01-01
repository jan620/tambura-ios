import SwiftUI
import MediaPlayer

struct MiniPlayerView: View {

    @StateObject private var volumeController = SystemVolumeController.shared
    @ObservedObject var player = RadioPlayer.shared
    @ObservedObject var storage: StationStorage
    @State private var isVisible = false

    var body: some View {
        Group {
            if player.currentStation != nil {
                content
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            isVisible = true
                        }
                    }
            }
        }
        .animation(
            .spring(response: 0.45, dampingFraction: 0.85),
            value: player.currentStation
        )
    }


    private var content: some View {
        VStack(spacing: 14) {

            // --- Top controls ---
            HStack(spacing: 14) {
                if let url = URL(string: player.currentStation?.imageURL ?? "") {
                    AsyncImage(url: url) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.isBuffering ? "Buffering…" : "Now Playing")
                        .animation(.easeInOut, value: player.isBuffering)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(player.currentTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    if player.isBuffering {
                        BufferingView()
                            .frame(width: 28, height: 20)
                            .transition(indicatorTransition)
                    } else {
                        Button {
                            if player.isPlaying {
                                player.stop(storage: storage)
                            } else {
                                player.resume()
                            }
                        } label: {
                            Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                                .font(.title3)
                        }
                        .transition(indicatorTransition)
                    }
                }
                .frame(width: 30, height: 30)
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.25),
                    value: player.isBuffering
                )


                AirPlayButton()
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 16)

            // --- Volume slider ---
            HStack(spacing: 10) {

                SystemVolumeSlider()
                    .frame(height: 30)

                Button {
                    volumeController.toggleMute()
                } label: {
                    Image(systemName: volumeController.isMuted
                          ? "speaker.slash.fill"
                          : "speaker.wave.2.fill")
                        .font(.title3)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .background(.thinMaterial)

            // --- NEW large equalizer ---
            /*
             LargeEqualizerView(
                shouldAnimate: player.isPlaying && !player.isBuffering
            )
            .frame(height: 44)
            .padding(.horizontal, 16)
            */
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var indicatorTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.85).combined(with: .opacity),
            removal: .scale(scale: 1.05).combined(with: .opacity)
        )
    }
}
