import SwiftUI
import UniformTypeIdentifiers
import SonicSwipeCore

struct RootView: View {
    @StateObject private var library = LibraryModel()
    @StateObject private var player = PlayerController()
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
                if player.current != nil {
                    NowPlayingBar(player: player)
                }
            }
            .navigationTitle("Sonic Swipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showImporter = true
                        } label: {
                            Label("Choose Folder in Files", systemImage: "folder")
                        }
                        Button {
                            player.stop()
                            library.openMockFolder()
                        } label: {
                            Label("Use Mock Tones (no USB)", systemImage: "waveform")
                        }
                        if library.canRescan {
                            Button {
                                library.rescan()
                            } label: {
                                Label("Rescan Folder", systemImage: "arrow.clockwise")
                            }
                        }
                    } label: {
                        Label("Folder", systemImage: "folder.badge.plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                player.stop()
                library.handlePickerResult(result)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch library.status {
        case .idle:
            EmptyStateView(showImporter: $showImporter, openMock: {
                library.openMockFolder()
            })
        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                Text("Reading folder")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            MessageView(
                symbol: "exclamationmark.triangle",
                title: "Folder problem",
                message: message
            )
        case .loaded:
            TrackListView(library: library, player: player)
        }
    }
}

private struct EmptyStateView: View {
    @Binding var showImporter: Bool
    let openMock: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Pick a music folder")
                .font(.title2.bold())
            Text("Plug in your USB drive, then choose the folder that holds your tracks. Sonic Swipe only reads files. It never changes your drive.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                showImporter = true
            } label: {
                Text("Choose Folder in Files")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Try Mock Tones (no USB)", action: openMock)
                .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxHeight: .infinity)
    }
}

struct MessageView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(title).font(.title3.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
