import SwiftUI
import SonicSwipeCore

struct NowPlayingBar: View {
    @ObservedObject var player: PlayerController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.current?.displayName ?? "")
                        .font(.headline)
                        .lineLimit(1)
                    statusLine
                }
                Spacer(minLength: 8)
                Button(action: player.togglePlayPause) {
                    Image(systemName: playPauseSymbol)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .disabled(!canToggle)
                .accessibilityLabel(playPauseLabel)

                Button(action: player.stop) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Stop and close player")
            }

            if case .failed = player.state {
                EmptyView()
            } else {
                ProgressView(value: progressValue)
                    .accessibilityLabel("Playback progress")
                HStack {
                    Text(PlaybackTime.format(player.currentTime))
                    Spacer()
                    Text(player.duration.map { PlaybackTime.format($0) } ?? "Length unknown")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch player.state {
        case .idle:
            EmptyView()
        case .loading:
            Text("Loading")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .playing:
            Text("Playing full track")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .paused:
            Text("Paused")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .finished:
            Text("Finished")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }

    private var progressValue: Double {
        guard let duration = player.duration, duration > 0 else { return 0 }
        return min(max(player.currentTime / duration, 0), 1)
    }

    private var canToggle: Bool {
        switch player.state {
        case .playing, .paused, .finished, .loading: return true
        case .idle, .failed: return false
        }
    }

    private var playPauseSymbol: String {
        switch player.state {
        case .playing, .loading: return "pause.fill"
        case .finished: return "arrow.counterclockwise"
        default: return "play.fill"
        }
    }

    private var playPauseLabel: String {
        switch player.state {
        case .playing, .loading: return "Pause"
        case .finished: return "Play again"
        default: return "Play"
        }
    }
}
