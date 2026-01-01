import SwiftUI

struct ContentView: View {
    
    @StateObject private var storage = StationStorage.shared
    @StateObject private var player = RadioPlayer.shared
    @Namespace private var tabNamespace
    @State private var bounceScale: CGFloat = 1.0
    @State private var isLoading: Bool = false
    
    @State private var selectedTab: Tab = .allStations

    enum Tab: String, CaseIterable, Identifiable {
        case favorites = "Favorites"
        case allStations = "Stations"
        
        var id: String { rawValue }
        var icon: Image? {
            switch self {
            case .favorites: return Image(systemName: "heart.fill")
            case .allStations: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            
            ZStack {
                VStack(spacing: 0) {
                    
                    // App Title
                    Text("Tambura")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    // Tabs
                    HStack(spacing: 0) {
                        ForEach(Tab.allCases) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                    selectedTab = tab
                                    bounceScale = 1.1
                                }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                                    bounceScale = 1.0
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if let icon = tab.icon {
                                        icon
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundColor(selectedTab == tab ? .white : .accentColor)
                                    }
                                    Text(tab.rawValue)
                                        .font(.headline)
                                        .foregroundColor(selectedTab == tab ? .white : .primary.opacity(0.6))
                                }
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    ZStack {
                                        if selectedTab == tab {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.accentColor)
                                                .matchedGeometryEffect(id: "tabBackground", in: tabNamespace)
                                        }
                                    }
                                )
                                .scaleEffect(selectedTab == tab ? bounceScale : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Stations List with Pull-to-Refresh
                    List {
                        ForEach(stationsForSelectedTab) { station in
                            StationRow(
                                station: station,
                                isSelected: storage.selectedStation == station,
                                isPlaying: player.isPlaying && storage.selectedStation == station,
                                isBuffering: player.isBuffering && storage.selectedStation == station
                            )
                            .onTapGesture {
                                storage.selectedStation = station
                                player.play(station: station)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadStations()
                    }
                    
                    // Mini Player
                    MiniPlayerView(storage: storage)
                        .padding(.bottom, 8)
                }
                
                // Overlay Spinner
                if isLoading {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(1.5)
                }
            }
        }
        .task {
            await storage.load()

            // 🔑 Now stations are available → favorites can be resolved
            if !storage.favoriteStations.isEmpty {
                selectedTab = .favorites
            }

            CarPlayManager.shared.configure(with: storage)
        }
    }
    
    // MARK: - Stations for selected tab
    private var stationsForSelectedTab: [Station] {
        switch selectedTab {
        case .favorites:
            return storage.favoriteStations
        case .allStations:
            return storage.stations
        }
    }
    
    // MARK: - Load Stations
    private func loadStations() async {
        isLoading = true
        await storage.load()
        isLoading = false
    }
}
