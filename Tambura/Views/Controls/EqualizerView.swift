import SwiftUI

struct EqualizerView: View {
    @State private var barHeights: [CGFloat] = Array(repeating: 0.3, count: 5)
    private let barCount = 5
    private let animationDuration = 0.4

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: max(2, barHeights[index] * 20))
            }
        }
        .onAppear {
            animateBars()
        }
    }

    private func animateBars() {
        withAnimation(Animation.linear(duration: animationDuration).repeatForever(autoreverses: true)) {
            for i in 0..<barCount {
                barHeights[i] = CGFloat.random(in: 0.3...1.0)
            }
        }

        // Update repeatedly for continuous animation
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            animateBars()
        }
    }
}
