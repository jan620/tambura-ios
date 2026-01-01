import SwiftUI

struct StationRow: View {
    let station: Station
    let isSelected: Bool
    let isPlaying: Bool
    let isBuffering: Bool

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var storage = StationStorage.shared
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {

            // Station artwork
            AsyncImage(url: URL(string: station.imageURL)) { image in
                image.resizable()
                     .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Station name only
            Text(station.name)
                .font(.headline)
                .lineLimit(1)
                .frame(maxHeight: .infinity, alignment: .center)

            Spacer()

            // Favorite heart button
            Button {
                withAnimation(.easeInOut) {
                    storage.toggleFavorite(station)
                }
            } label: {
                Image(systemName: storage.isFavorite(station) ? "heart.fill" : "heart")
                    .foregroundColor(.blue) // favorite color
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Right-side indicator
            ZStack {
                if isSelected && isBuffering {
                    BufferingView()
                        .transition(indicatorTransition)
                } else if isSelected && isPlaying && !isBuffering {
                    EqualizerView()
                        .transition(indicatorTransition)
                } else if let code = station.country, !code.isEmpty {
                    Text(flagEmoji(from: code))
                        .font(.system(size: 30))
                        .transition(.opacity)
                        .accessibilityLabel(code)
                }
            }
            .frame(width: 30, height: 20)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isBuffering)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isPlaying)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(selectionBackground)
        .cornerRadius(16)
        .contentShape(Rectangle())
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hover
            }
        }
    }

    // MARK: - Background
    private var selectionBackground: some View {
        Group {
            if isSelected {
                Color.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.15)
            } else if isHovered {
                Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Transitions
    private var indicatorTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.85, anchor: .center).combined(with: .opacity),
            removal: .scale(scale: 1.05, anchor: .center).combined(with: .opacity)
        )
    }
}

// MARK: - Flag Helper
private func flagEmoji(from countryCode: String) -> String {
    countryCode
        .uppercased()
        .unicodeScalars
        .compactMap { UnicodeScalar(127397 + $0.value) }
        .map { String($0) }
        .joined()
}
