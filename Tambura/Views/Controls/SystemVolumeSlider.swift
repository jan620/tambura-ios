import SwiftUI
import MediaPlayer

struct SystemVolumeSlider: UIViewRepresentable {

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)

        volumeView.showsRouteButton = false
        volumeView.showsVolumeSlider = true

        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
    }
}
