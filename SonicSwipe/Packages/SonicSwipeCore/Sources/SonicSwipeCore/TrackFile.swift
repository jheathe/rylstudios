import Foundation

/// File extensions the Phase 0 scanner looks for.
///
/// This is a list of files worth TRYING, not a promise that AVFoundation can
/// play them. Real support is only known after an actual play attempt on the
/// target iPhone, which the app records per track.
public enum AudioFormat {
    public static let probeExtensions: [String] = ["mp3", "m4a", "wav", "aiff", "aif", "flac"]

    public static func isProbeCandidate(pathExtension: String) -> Bool {
        probeExtensions.contains(pathExtension.lowercased())
    }
}

/// One audio file found in the selected folder. Read only description of a file.
public struct TrackFile: Identifiable, Hashable, Sendable {
    public let url: URL
    /// Path relative to the selected folder, using "/" separators.
    /// Phase 0 uses this as the id. A stable cross drive identifier is Phase 2 work.
    public let relativePath: String
    public let fileSize: Int64?

    public var id: String { relativePath }

    /// Lowercased extension such as "mp3".
    public var fileExtension: String { url.pathExtension.lowercased() }

    /// File name without extension. Title and artist metadata come in a later phase.
    public var displayName: String { url.deletingPathExtension().lastPathComponent }

    public init(url: URL, relativePath: String, fileSize: Int64?) {
        self.url = url
        self.relativePath = relativePath
        self.fileSize = fileSize
    }
}
