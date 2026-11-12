import Foundation
import SonicSwipeCore

/// Holds the selected folder and the tracks found in it.
///
/// Access rules for Phase 0:
/// - The folder comes from the Files picker (user initiated).
/// - Security scoped access is kept open while the folder is in use, because
///   playback reads files under it later, not only during the scan.
/// - Nothing is ever written to the folder.
final class LibraryModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case scanning
        case loaded
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var folderName: String?
    @Published private(set) var tracks: [TrackFile] = []
    @Published private(set) var ignoredFileCount = 0
    @Published private(set) var unreadableFolderCount = 0
    @Published private(set) var isMock = false

    private var folderURL: URL?
    private var holdsSecurityScope = false
    private var scanToken = UUID()

    var canRescan: Bool { folderURL != nil }

    deinit { releaseAccess() }

    // MARK: Opening folders

    /// Handles the result of SwiftUI `fileImporter` with `[.folder]`.
    func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            openFolder(url, isMock: false)
        case .failure(let error):
            status = .failed("The folder picker failed: \(error.localizedDescription)")
        }
    }

    func openMockFolder() {
        do {
            let url = try MockLibrary.create(inside: FileManager.default.temporaryDirectory)
            openFolder(url, isMock: true)
        } catch {
            status = .failed("Could not create the mock folder: \(error.localizedDescription)")
        }
    }

    func rescan() {
        guard let url = folderURL else { return }
        scan(url)
    }

    private func openFolder(_ url: URL, isMock: Bool) {
        releaseAccess()
        folderURL = url
        folderName = url.lastPathComponent
        self.isMock = isMock
        tracks = []
        ignoredFileCount = 0
        unreadableFolderCount = 0

        if !isMock {
            // Returns false for URLs that are not security scoped. We still try to
            // read them; a real permission problem shows up as a scan error.
            holdsSecurityScope = url.startAccessingSecurityScopedResource()
        }
        scan(url)
    }

    private func releaseAccess() {
        if holdsSecurityScope, let url = folderURL {
            url.stopAccessingSecurityScopedResource()
        }
        holdsSecurityScope = false
    }

    // MARK: Scanning

    private func scan(_ url: URL) {
        let token = UUID()
        scanToken = token
        status = .scanning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = Result { try Self.coordinatedScan(root: url) }
            DispatchQueue.main.async {
                guard let self, self.scanToken == token else { return } // a newer scan replaced this one
                switch outcome {
                case .success(let scan):
                    self.tracks = scan.tracks
                    self.ignoredFileCount = scan.ignoredFileCount
                    self.unreadableFolderCount = scan.unreadableFolderCount
                    self.status = .loaded
                case .failure(let error):
                    self.tracks = []
                    self.status = .failed(Self.describe(scanError: error))
                }
            }
        }
    }

    /// Reads the folder through NSFileCoordinator, the pattern Apple documents for
    /// folders handed over by the document picker. `.withoutChanges` requests read
    /// access only.
    private static func coordinatedScan(root: URL) throws -> ScanResult {
        var coordinationError: NSError?
        var outcome: Result<ScanResult, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: root,
            options: [.withoutChanges],
            error: &coordinationError
        ) { coordinatedURL in
            outcome = Result { try TrackScanner.scan(root: coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        return try outcome.get()
    }

    private static func describe(scanError error: Error) -> String {
        "Could not read this folder. If it is on a USB drive, check that the drive is still connected and shows up in the Files app. Details: \(error.localizedDescription)"
    }
}
