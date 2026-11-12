import Foundation

/// Generates a plain 16 bit mono PCM WAV tone in memory.
public enum ToneWAV {
    public static func data(
        frequency: Double,
        duration: Double,
        sampleRate: Int = 44_100,
        amplitude: Double = 0.25
    ) -> Data {
        let frameCount = max(0, Int(duration * Double(sampleRate)))
        let dataByteCount = frameCount * 2
        let fadeFrames = max(1, sampleRate / 100) // 10 ms fades avoid clicks

        var out = Data()
        out.reserveCapacity(44 + dataByteCount)
        out.append(contentsOf: Array("RIFF".utf8))
        out.append(le32(UInt32(36 + dataByteCount)))
        out.append(contentsOf: Array("WAVE".utf8))
        out.append(contentsOf: Array("fmt ".utf8))
        out.append(le32(16))                         // PCM chunk size
        out.append(le16(1))                          // PCM format
        out.append(le16(1))                          // mono
        out.append(le32(UInt32(sampleRate)))
        out.append(le32(UInt32(sampleRate * 2)))     // byte rate
        out.append(le16(2))                          // block align
        out.append(le16(16))                         // bits per sample
        out.append(contentsOf: Array("data".utf8))
        out.append(le32(UInt32(dataByteCount)))

        for i in 0..<frameCount {
            let t = Double(i) / Double(sampleRate)
            var gain = amplitude
            if i < fadeFrames { gain *= Double(i) / Double(fadeFrames) }
            if frameCount - i <= fadeFrames { gain *= Double(frameCount - i) / Double(fadeFrames) }
            let sample = Int16((sin(2 * .pi * frequency * t) * gain * Double(Int16.max)).rounded())
            out.append(le16(UInt16(bitPattern: sample)))
        }
        return out
    }

    private static func le16(_ v: UInt16) -> Data {
        withUnsafeBytes(of: v.littleEndian) { Data($0) }
    }

    private static func le32(_ v: UInt32) -> Data {
        withUnsafeBytes(of: v.littleEndian) { Data($0) }
    }
}

/// A clearly labeled MOCK folder for testing without a USB drive.
/// Everything is written to a folder the caller chooses (the app passes its own
/// temporary directory). It never touches a real library.
public enum MockLibrary {
    public static let folderName = "SonicSwipeMock"

    /// Creates the mock folder inside `parent` and returns its URL.
    /// Replaces a previous mock folder of the same name.
    @discardableResult
    public static func create(inside parent: URL, fileManager: FileManager = .default) throws -> URL {
        let root = parent.appendingPathComponent(folderName, isDirectory: true)
        if fileManager.fileExists(atPath: root.path) {
            try fileManager.removeItem(at: root)
        }
        let nested = root.appendingPathComponent("Nested Folder", isDirectory: true)
        try fileManager.createDirectory(at: nested, withIntermediateDirectories: true)

        try ToneWAV.data(frequency: 440, duration: 6)
            .write(to: root.appendingPathComponent("MOCK Tone A 440Hz.wav"))
        try ToneWAV.data(frequency: 330, duration: 6)
            .write(to: root.appendingPathComponent("MOCK Tone B 330Hz.wav"))
        try ToneWAV.data(frequency: 550, duration: 6)
            .write(to: nested.appendingPathComponent("MOCK Tone C 550Hz.wav"))

        // Deliberately not audio, to exercise the "could not play" reporting.
        try Data("This is not real audio.".utf8)
            .write(to: root.appendingPathComponent("MOCK Broken File.mp3"))
        // Deliberately not a supported extension, to exercise the ignored file count.
        try Data("notes".utf8)
            .write(to: root.appendingPathComponent("MOCK notes.txt"))
        return root
    }
}
