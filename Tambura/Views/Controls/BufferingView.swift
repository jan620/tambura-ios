import SwiftUI

struct BufferingView: View {
    @State private var scale: CGFloat = 1

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 10, height: 10)
            .scaleEffect(scale)
            .opacity(Double(2 - scale))
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.6
                }
            }
    }
}
