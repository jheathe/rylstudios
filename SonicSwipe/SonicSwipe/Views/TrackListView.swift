import SwiftUI
import SonicSwipeCore

struct TrackListView: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var player: PlayerController

    var body: some View {
        List {
            Section {
                ForEach(library.tracks) { track in
                    Button {
                        player.play(track)
                    } label: {
                        TrackRow(
                            track: track,
                            isCurrent: player.current?.id == track.id,
                            report: player.reports[track.id]
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                header
            } footer: {
                footer
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if library.tracks.isEmpty {
                MessageView(
                    symbol: "music.note.list",
                    title: "No audio files found",
                    message: "Looked for \(AudioFormat.probeExtensions.joined(separator: ", ")) in this folder and its subfolders. Try a different folder."
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if library.isMock {
                Label("MOCK DATA. Generated test tones, not your music.", systemImage: "exclamationmark.circle")
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)
            }
            Text("\(library.folderName ?? "Folder"): \(library.tracks.count) tracks")
                .textCase(nil)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private var footer: some View {
        let parts = footerParts
        if !parts.isEmpty {
            Text(parts.joined(separator: " "))
        }
    }

    private var footerParts: [String] {
        var parts: [String] = []
        if library.ignoredFileCount > 0 {
            parts.append("\(library.ignoredFileCount) other files were ignored.")
        }
        if library.unreadableFolderCount > 0 {
            parts.append("\(library.unreadableFolderCount) subfolders could not be read.")
        }
        parts.append("Plays or Could not play shows what happened on this iPhone when you tapped the track.")
        return parts
    }
}

private struct TrackRow: View {
    let track: TrackFile
    let isCurrent: Bool
    let report: PlaybackReport?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                .frame(width: 24)
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(track.fileExtension.uppercased())
                        .font(.caption.monospaced())
                    if let size = track.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption)
                    }
                    reportBadge
                }
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Plays this track from the beginning")
    }

    @ViewBuilder
    private var reportBadge: some View {
        switch report {
        case .played:
            Label("Plays", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Label("Could not play", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        case nil:
            EmptyView()
        }
    }
}
