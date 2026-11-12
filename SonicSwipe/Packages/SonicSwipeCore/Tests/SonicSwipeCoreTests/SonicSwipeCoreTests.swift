import XCTest
@testable import SonicSwipeCore

final class SonicSwipeCoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SonicSwipeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func touch(_ relative: String, contents: String = "x") throws {
        let url = tempRoot.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    // MARK: Scanner

    func testFindsSupportedExtensionsCaseInsensitivelyAndRecursively() throws {
        try touch("a.mp3")
        try touch("b.WAV")
        try touch("Sub/c.m4a")
        try touch("Sub/Deeper/d.flac")
        try touch("e.aif")
        try touch("f.aiff")

        let result = try TrackScanner.scan(root: tempRoot)
        XCTAssertEqual(
            result.tracks.map(\.relativePath),
            ["a.mp3", "b.WAV", "e.aif", "f.aiff", "Sub/c.m4a", "Sub/Deeper/d.flac"].sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
        )
        XCTAssertEqual(result.ignoredFileCount, 0)
    }

    func testIgnoresHiddenAppleDoubleAndUnsupportedFiles() throws {
        try touch("real.mp3")
        try touch("._real.mp3")       // macOS resource fork stub on USB drives
        try touch(".hidden.wav")
        try touch("cover.jpg")
        try touch("notes.txt")

        let result = try TrackScanner.scan(root: tempRoot)
        XCTAssertEqual(result.tracks.map(\.relativePath), ["real.mp3"])
        XCTAssertEqual(result.ignoredFileCount, 2) // cover.jpg and notes.txt; hidden files are not counted
    }

    func testDisplayNameAndExtension() throws {
        try touch("Artist - Title (Extended Mix).MP3")
        let track = try XCTUnwrap(TrackScanner.scan(root: tempRoot).tracks.first)
        XCTAssertEqual(track.displayName, "Artist - Title (Extended Mix)")
        XCTAssertEqual(track.fileExtension, "mp3")
        XCTAssertEqual(track.fileSize, 1)
    }

    func testMissingFolderThrows() {
        let missing = tempRoot.appendingPathComponent("does-not-exist")
        XCTAssertThrowsError(try TrackScanner.scan(root: missing))
    }

    func testEmptyFolderReturnsNoTracks() throws {
        let result = try TrackScanner.scan(root: tempRoot)
        XCTAssertTrue(result.tracks.isEmpty)
    }

    /// Phase 0 acceptance: scanning must leave the source folder untouched.
    func testScanDoesNotModifyFolder() throws {
        try touch("a.mp3", contents: "audio bytes")
        try touch("Sub/b.wav", contents: "more audio bytes")
        try touch("skip.txt")

        func snapshot() throws -> [String: (Int, Date)] {
            var out: [String: (Int, Date)] = [:]
            let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
            let e = FileManager.default.enumerator(at: tempRoot, includingPropertiesForKeys: Array(keys))!
            for case let url as URL in e {
                let v = try url.resourceValues(forKeys: keys)
                if v.isRegularFile == true {
                    out[url.lastPathComponent] = (v.fileSize ?? -1, v.contentModificationDate ?? .distantPast)
                }
            }
            return out
        }

        let before = try snapshot()
        _ = try TrackScanner.scan(root: tempRoot)
        _ = try TrackScanner.scan(root: tempRoot)
        let after = try snapshot()

        XCTAssertEqual(before.keys.sorted(), after.keys.sorted())
        for (name, value) in before {
            XCTAssertEqual(value.0, after[name]?.0, "size changed for \(name)")
            XCTAssertEqual(value.1, after[name]?.1, "modification date changed for \(name)")
        }
    }

    // MARK: Format list

    func testProbeExtensionsMatchBrief() {
        XCTAssertEqual(Set(AudioFormat.probeExtensions), ["mp3", "m4a", "wav", "aiff", "aif", "flac"])
        XCTAssertTrue(AudioFormat.isProbeCandidate(pathExtension: "MP3"))
        XCTAssertFalse(AudioFormat.isProbeCandidate(pathExtension: "ogg"))
    }

    // MARK: Time formatting

    func testPlaybackTimeFormat() {
        XCTAssertEqual(PlaybackTime.format(0), "0:00")
        XCTAssertEqual(PlaybackTime.format(5.9), "0:05")
        XCTAssertEqual(PlaybackTime.format(65), "1:05")
        XCTAssertEqual(PlaybackTime.format(3600), "60:00")
        XCTAssertEqual(PlaybackTime.format(nil), "0:00")
        XCTAssertEqual(PlaybackTime.format(.nan), "0:00")
        XCTAssertEqual(PlaybackTime.format(-3), "0:00")
    }

    // MARK: Mock WAV and mock folder

    func testToneWAVHeaderAndSize() throws {
        let wav = ToneWAV.data(frequency: 440, duration: 1, sampleRate: 8_000)
        XCTAssertEqual(wav.count, 44 + 8_000 * 2)
        XCTAssertEqual(String(decoding: wav[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: wav[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(String(decoding: wav[12..<16], as: UTF8.self), "fmt ")
        XCTAssertEqual(String(decoding: wav[36..<40], as: UTF8.self), "data")

        func u32(_ offset: Int) -> UInt32 {
            (0..<4).reduce(UInt32(0)) { $0 | UInt32(wav[wav.startIndex + offset + $1]) << (8 * UInt32($1)) }
        }
        func u16(_ offset: Int) -> UInt16 {
            UInt16(wav[wav.startIndex + offset]) | UInt16(wav[wav.startIndex + offset + 1]) << 8
        }
        XCTAssertEqual(u32(4), UInt32(wav.count - 8))   // RIFF chunk size
        XCTAssertEqual(u16(20), 1)                      // PCM
        XCTAssertEqual(u16(22), 1)                      // mono
        XCTAssertEqual(u32(24), 8_000)                  // sample rate
        XCTAssertEqual(u16(34), 16)                     // bits
        XCTAssertEqual(u32(40), UInt32(8_000 * 2))      // data size
    }

    func testMockLibraryCreatesScannableFolder() throws {
        let root = try MockLibrary.create(inside: tempRoot)
        let result = try TrackScanner.scan(root: root)
        XCTAssertEqual(result.tracks.count, 4) // three tones plus the deliberately broken mp3
        XCTAssertEqual(result.ignoredFileCount, 1) // the txt note
        XCTAssertTrue(result.tracks.allSatisfy { $0.displayName.hasPrefix("MOCK") })

        // Creating it again replaces it instead of failing or duplicating.
        let again = try MockLibrary.create(inside: tempRoot)
        XCTAssertEqual(try TrackScanner.scan(root: again).tracks.count, 4)
    }
}
