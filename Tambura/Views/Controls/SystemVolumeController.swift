import Foundation
import SwiftUI
import MediaPlayer
import AVFoundation
import Combine

final class SystemVolumeController: ObservableObject {

    static let shared = SystemVolumeController()

    @Published var isMuted = false

    private var previousVolume: Float = 0.5

    private init() {}

    func toggleMute() {

        if isMuted {

            // Restore previous volume
            let restoredVolume = max(previousVolume, 0.1)
            setSystemVolume(restoredVolume)

            isMuted = false

        } else {

            // Save current device volume
            let currentVolume = AVAudioSession.sharedInstance().outputVolume

            if currentVolume > 0.01 {
                previousVolume = currentVolume
            }

            setSystemVolume(0)

            isMuted = true
        }
    }

    // MARK: - System Volume

    private func setSystemVolume(_ value: Float) {

        let volumeView = MPVolumeView(frame: .zero)

        guard let slider = volumeView.subviews.first(where: {
            $0 is UISlider
        }) as? UISlider else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            slider.value = value

            // IMPORTANT
            slider.sendActions(for: .valueChanged)
        }
    }
}
