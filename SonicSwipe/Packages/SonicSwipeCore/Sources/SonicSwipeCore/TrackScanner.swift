import Foundation

public struct ScanResult: Equatable, Sendable {
    public var tracks: [TrackFile]
    /// Regular files skipped because their extension is not in the probe list.
    public var ignoredFileCount: Int
    /// Subfolders that could not be read. The scan continues past them.
    public var unreadableFolderCount: Int

    public init(tracks: [TrackFile] = [], ignoredFileCount: Int = 0, unreadableFolderCount: Int = 0) {
        self.tracks = tracks
        self.ignoredFileCount = ignoredFileCount
        self.unreadableFolderCount = unreadableFolderCount
    }
}

/// Lists audio files under a folder. Strictly read only: it never creates,
/// renames, deletes or writes anything.
public enum TrackScanner {
    /// Guards against very deep trees. Symbolic links are skipped, so loops are not followed.
    public static let maxDepth = 16

    /// - Throws: if the top level folder itself cannot be read.
    public static func scan(root: URL, fileManager: FileManager = .default) throws -> ScanResult {
        var result = ScanResult()
        try walk(directory: root, relativePrefix: "", depth: 0, fileManager: fileManager, into: &result, isTopLevel: true)
        result.tracks.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        return result
    }

    private static func walk(
        directory: URL,
        relativePrefix: String,
        depth: Int,
        fileManager: FileManager,
        into result: inout ScanResult,
        isTopLevel: Bool
    ) throws {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        let items: [URL]
        do {
            // skipsHiddenFiles also skips macOS "._name.mp3" AppleDouble stubs that
            // show up on USB drives and are not real audio.
            items = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )
        } catch {
            if isTopLevel { throw error }
            result.unreadableFolderCount += 1
            return
        }

        for item in items {
            guard let values = try? item.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true { continue }

            let name = item.lastPathComponent
            if values.isDirectory == true {
                if depth < maxDepth {
                    try walk(
                        directory: item,
                        relativePrefix: relativePrefix + name + "/",
                        depth: depth + 1,
                        fileManager: fileManager,
                        into: &result,
                        isTopLevel: false
                    )
                }
            } else if values.isRegularFile == true {
                if AudioFormat.isProbeCandidate(pathExtension: item.pathExtension) {
                    result.tracks.append(
                        TrackFile(
                            url: item,
                            relativePath: relativePrefix + name,
                            fileSize: values.fileSize.map { Int64($0) }
                        )
                    )
                } else {
                    result.ignoredFileCount += 1
                }
            }
        }
    }
}
