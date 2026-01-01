import SwiftUI

struct LargeEqualizerView: View {
    let shouldAnimate: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var barValues: [CGFloat] = Array(repeating: 0.15, count: 20)
    @State private var timer: Timer?

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(barValues.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(barGradient)
                    .frame(height: max(6, barValues[index] * 44))
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { update() }
        .onDisappear { stop() }
        .onChange(of: shouldAnimate) { _ in update() }
        .animation(.easeInOut(duration: 0.25), value: barValues)
    }

    // MARK: - Control

    private func update() {
        shouldAnimate ? start() : stop()
    }

    private func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in
            barValues = barValues.map { _ in
                CGFloat.random(in: 0.25...1.0)
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        barValues = barValues.map { _ in 0.15 }
    }

    // MARK: - Styling

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.25),
                Color.accentColor.opacity(0.9)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}
