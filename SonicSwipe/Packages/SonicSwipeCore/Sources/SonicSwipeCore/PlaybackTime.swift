import Foundation

public enum PlaybackTime {
    /// "m:ss" for display. Unknown, negative or non finite values show "0:00".
    public static func format(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
