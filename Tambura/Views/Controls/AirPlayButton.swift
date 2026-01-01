import SwiftUI
import AVKit
import AVFoundation

struct AirPlayButton: View {
    @State private var isActive = false

    var body: some View {
        AVRoutePickerViewWrapper(isActive: $isActive)
            .frame(width: 30, height: 30)
    }
}

struct AVRoutePickerViewWrapper: UIViewRepresentable {
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        picker.delegate = context.coordinator
        picker.tintColor = UIColor.label // default inactive
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // Update tint color based on isActive binding
        UIView.animate(withDuration: 0.25) {
            uiView.tintColor = self.isActive ? UIColor.systemBlue : UIColor.label
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isActive: $isActive)
    }

    class Coordinator: NSObject, AVRoutePickerViewDelegate {
        @Binding var isActive: Bool

        init(isActive: Binding<Bool>) {
            _isActive = isActive
            super.init()
            // Observe route changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(routeChanged),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )
            updateActiveState()
        }

        @objc private func routeChanged(_ notification: Notification) {
            updateActiveState()
        }

        private func updateActiveState() {
            let currentRoute = AVAudioSession.sharedInstance().currentRoute
            // If output is AirPlay (or multiple outputs), set active
            isActive = currentRoute.outputs.contains(where: { $0.portType == .airPlay })
        }
    }
}
