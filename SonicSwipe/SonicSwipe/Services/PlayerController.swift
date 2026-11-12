import AVFoundation
import Combine
import Foundation
import SonicSwipeCore

enum PlaybackState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case finished
    case failed(String)
}

/// What actually happened the last time we tried to play a file on this iPhone.
/// This is the only honest way to know codec support, so the track list shows it.
enum PlaybackReport: Equatable {
    case played
    case failed(String)
}

/// Phase 0 player: one track at a time, full track, from the beginning.
/// Preview mode, next track and auto advance belong to Phase 1.
///
/// All AVFoundation callbacks are delivered on the main queue.
final class PlayerController: ObservableObject {
    @Published private(set) var current: TrackFile?
    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double?
    @Published private(set) var reports: [TrackFile.ID: PlaybackReport] = [:]

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var stallCheck: DispatchWorkItem?

    deinit { teardown() }

    // MARK: Controls

    func play(_ track: TrackFile) {
        teardown()
        current = track
        currentTime = 0
        duration = nil
        state = .loading

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            fail(track, "Could not start the audio session: \(error.localizedDescription)")
            return
        }

        // Fast, clear message when the drive was unplugged before tapping.
        do {
            _ = try track.url.checkResourceIsReachable()
        } catch {
            fail(track, Self.unreachableMessage)
            return
        }

        let item = AVPlayerItem(url: track.url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.itemStatusChanged(status, item: item, track: track) }
            .store(in: &cancellables)

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.timeControlChanged(status, track: track) }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.didFinish() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self?.fail(track, Self.playbackStoppedMessage(error))
            }
            .store(in: &cancellables)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if seconds.isFinite { self.currentTime = seconds }
        }

        player.play()
    }

    func togglePlayPause() {
        guard let player else { return }
        switch state {
        case .playing, .loading:
            player.pause()
        case .paused:
            player.play()
        case .finished:
            player.seek(to: .zero) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.currentTime = 0
                    self?.player?.play()
                }
            }
        case .idle, .failed:
            break
        }
    }

    func stop() {
        teardown()
        current = nil
        state = .idle
        currentTime = 0
        duration = nil
    }

    // MARK: Observation

    private func itemStatusChanged(_ status: AVPlayerItem.Status, item: AVPlayerItem, track: TrackFile) {
        switch status {
        case .readyToPlay:
            let seconds = item.duration.seconds
            duration = seconds.isFinite && seconds > 0 ? seconds : nil
            if reports[track.id] != .played { reports[track.id] = .played }
        case .failed:
            fail(track, Self.cannotPlayMessage(for: track, error: item.error))
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func timeControlChanged(_ status: AVPlayer.TimeControlStatus, track: TrackFile) {
        // Do not overwrite a failure or the finished state with a late pause event.
        if case .failed = state { return }
        if state == .finished { return }

        switch status {
        case .playing:
            stallCheck?.cancel()
            state = .playing
        case .paused:
            // AVPlayer reports "paused" before the item is ready. Stay in "loading" until then.
            if duration != nil { state = .paused }
        case .waitingToPlayAtSpecifiedRate:
            state = .loading
            scheduleStallCheck(track: track)
        @unknown default:
            break
        }
    }

    /// If playback keeps waiting and the file is no longer reachable, the drive
    /// was most likely unplugged. Say so instead of spinning forever.
    private func scheduleStallCheck(track: TrackFile) {
        stallCheck?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .loading, self.current?.id == track.id else { return }
            if (try? track.url.checkResourceIsReachable()) != true {
                self.fail(track, Self.unreachableMessage)
            }
        }
        stallCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func didFinish() {
        player?.pause()
        if let duration { currentTime = duration }
        state = .finished
    }

    private func fail(_ track: TrackFile, _ message: String) {
        reports[track.id] = .failed(message)
        teardown()
        state = .failed(message)
    }

    private func teardown() {
        stallCheck?.cancel()
        stallCheck = nil
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        cancellables.removeAll()
        player?.pause()
        player = nil
    }

    // MARK: Messages

    private static let unreachableMessage =
        "This file is not reachable. If it is on a USB drive, the drive may have been unplugged. Reconnect it, then rescan and try again."

    private static func cannotPlayMessage(for track: TrackFile, error: Error?) -> String {
        let detail = error?.localizedDescription ?? "no further detail"
        return "AVFoundation could not play this .\(track.fileExtension) file on this iPhone (\(detail)). It may be an unsupported format or a damaged file."
    }

    private static func playbackStoppedMessage(_ error: Error?) -> String {
        let detail = error?.localizedDescription ?? "no further detail"
        return "Playback stopped before the end (\(detail)). If the file is on a USB drive, it may have been unplugged."
    }
}
