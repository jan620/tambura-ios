import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

@MainActor
final class RadioPlayer: ObservableObject {

    static let shared = RadioPlayer()

    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentStation: Station?
    @Published var volume: Float = 0.5
    @Published var currentTitle: String = ""

    private let player = AVPlayer()
    private var timeControlObserver: NSKeyValueObservation?
    private var artworkCache: [String: MPMediaItemArtwork] = [:]

    // Stored observer tokens so they are never duplicated
    private var stallObserver: Any?
    private var failObserver: Any?
    private var interruptionObserver: Any?

    init() {
        setupAudioSession()
        setupRemoteCommands()
        setupInterruptionHandling()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearArtworkCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func clearArtworkCache() {
        artworkCache.removeAll()
    }

    // MARK: - Interruption Handling (set up once in init)

    private func setupInterruptionHandling() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            if type == .ended {
                let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    self.activateAudioSessionIfNeeded()
                    self.player.play()
                    self.isPlaying = true
                    MPNowPlayingInfoCenter.default().playbackState = .playing
                }
            }
        }
    }

    // MARK: - Playback

    func play(station: Station) {
        activateAudioSessionIfNeeded()

        if currentStation?.id == station.id {
            if !isPlaying { resume() }
            return
        }

        // Remove previous per-item observers
        if let o = stallObserver { NotificationCenter.default.removeObserver(o) }
        if let o = failObserver  { NotificationCenter.default.removeObserver(o) }

        currentStation = station
        currentTitle = station.name
        isBuffering = true

        guard let url = URL(string: station.streamURL) else { return }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        // Stream failed to reach end (network error etc.)
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            print("❌ Stream failed:", notification.userInfo ?? [:])
            self?.reconnect()
        }

        // Stream stalled: reconnect with a fresh AVPlayerItem instead of just play()
        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ Playback stalled — reconnecting")
            self?.reconnect()
        }

        player.volume = volume
        observeBuffering(for: item)
        player.play()
        isPlaying = true

        setupNowPlaying(station: station)
    }

    func pause() {
        player.pause()
        isPlaying = false
        isBuffering = false
        MPNowPlayingInfoCenter.default().playbackState = .paused
    }

    func resume() {
        activateAudioSessionIfNeeded()
        player.play()
        isPlaying = true
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    func stop(storage: StationStorage) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        isBuffering = false
        currentStation = nil
        currentTitle = ""

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped

        storage.selectedStation = nil
    }

    // MARK: - Reconnect

    /// Creates a fresh AVPlayerItem for the current station URL and restarts playback.
    /// Required after a stall or network error — play() alone won't recover a dead stream.
    private func reconnect() {
        guard let station = currentStation,
              let url = URL(string: station.streamURL) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            // Remove old per-item observers first
            if let o = self.stallObserver { NotificationCenter.default.removeObserver(o) }
            if let o = self.failObserver  { NotificationCenter.default.removeObserver(o) }

            let newItem = AVPlayerItem(url: url)
            self.player.replaceCurrentItem(with: newItem)

            // Re-attach per-item observers to the new item
            self.failObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: newItem, queue: .main
            ) { [weak self] _ in self?.reconnect() }

            self.stallObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemPlaybackStalled,
                object: newItem, queue: .main
            ) { [weak self] _ in self?.reconnect() }

            self.observeBuffering(for: newItem)
            self.player.play()
        }
    }

    // MARK: - Audio Session

    private func activateAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("❌ Audio session activation failed:", error)
        }
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
        try? session.setActive(true)
    }

    // MARK: - Buffering Observer

    private func observeBuffering(for item: AVPlayerItem) {
        timeControlObserver?.invalidate()

        timeControlObserver = player.observe(
            \.timeControlStatus,
            options: [.initial, .new]
        ) { [weak self] player, _ in
            guard let self else { return }

            DispatchQueue.main.async {
                switch player.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                    self.isPlaying = true
                case .playing:
                    self.isBuffering = false
                    self.isPlaying = true
                case .paused:
                    self.isBuffering = false
                    self.isPlaying = false
                @unknown default:
                    self.isBuffering = false
                    self.isPlaying = false
                }
            }
        }
    }

    // MARK: - Now Playing

    private func setupNowPlaying(station: Station) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: station.name,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .playing

        // Artwork: use cache or fetch asynchronously (never block the main thread)
        if let cached = artworkCache[station.id] {
            info[MPMediaItemPropertyArtwork] = cached
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            return
        }

        Task.detached { [weak self] in
            guard let self,
                  let url = URL(string: station.imageURL),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data)
            else { return }

            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

            await MainActor.run {
                self.artworkCache[station.id] = artwork
                var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                updated[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
            }
        }
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.resume()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNextStation()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPreviousStation()
            return .success
        }
    }

    // MARK: - Station Navigation

    private func playNextStation() {
        let storage = StationStorage.shared
        guard let next = storage.nextStation(from: storage.selectedStation) else { return }
        storage.selectedStation = next
        play(station: next)
    }

    private func playPreviousStation() {
        let storage = StationStorage.shared
        guard let prev = storage.previousStation(from: storage.selectedStation) else { return }
        storage.selectedStation = prev
        play(station: prev)
    }
}
