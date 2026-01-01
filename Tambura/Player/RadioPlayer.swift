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
    private var endObserver: Any?
    
    
    init() {
        setupAudioSession()
        setupRemoteCommands()

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


    func play(station: Station) {
        activateAudioSessionIfNeeded()

        if currentStation?.id == station.id {
            // Optional: resume if paused
            if !isPlaying {
                resume()
            }
            return
        }

        currentStation = station
        currentTitle = station.name
        isBuffering = true

        guard let url = URL(string: station.streamURL) else { return }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { notification in
            print("❌ Stream failed:", notification.userInfo ?? [:])
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { notification in
            print("⚠️ Audio interruption:", notification.userInfo ?? [:])
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 App resigned active")
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🌙 App entered background")
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            print("⚠️ Playback stalled — retrying")

            self?.player.pause()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.player.play()
            }
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

    private func activateAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay]
            )

            try session.setActive(true)
        } catch {
            print("❌ Audio session activation failed:", error)
        }
    }



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


    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
        try? session.setActive(true)
    }


    private func setupNowPlaying(station: Station) {
        var nowPlaying: [String: Any] = [
            MPMediaItemPropertyTitle: station.name,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying

        if let cachedArtwork = artworkCache[station.id] {
            nowPlaying[MPMediaItemPropertyArtwork] = cachedArtwork
        } else if let url = URL(string: station.imageURL),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) {

            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

            artworkCache[station.id] = artwork
            nowPlaying[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }



    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // Play
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.resume()
            return .success
        }

        // Pause
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
