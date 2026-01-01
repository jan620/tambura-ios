import Foundation
import SwiftUI
import Combine

@MainActor
final class StationStorage: ObservableObject {

    static let shared = StationStorage()

    @Published var stations: [Station] = []
    @Published var selectedStation: Station?
    @Published private(set) var favoriteStationIDs: Set<String> = [] {
        didSet {
            saveFavorites()
        }
    }

    private let service = Webservice()
    private let favoritesKey = "favoriteStationIDs"

    private init() {
        loadFavorites()
    }


    func isFavorite(_ station: Station) -> Bool {
        favoriteStationIDs.contains(station.id)
    }

    func toggleFavorite(_ station: Station) {
        if favoriteStationIDs.contains(station.id) {
            favoriteStationIDs.remove(station.id)
        } else {
            favoriteStationIDs.insert(station.id)
        }
        saveFavorites()
    }

    var favoriteStations: [Station] {
        // Only include stations that exist in the current list
        stations.filter { favoriteStationIDs.contains($0.id) }
    }


    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteStationIDs), forKey: favoritesKey)
    }

    private func loadFavorites() {
        favoriteStationIDs = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
    }


    var groupedStations: [String: [Station]] {
        Dictionary(grouping: stations, by: \.type)
    }

    var orderedTypes: [String] {
        let preferredOrder = ["stream", "radio"]
        return preferredOrder.filter { groupedStations[$0] != nil }
            + groupedStations.keys.filter { !preferredOrder.contains($0) }.sorted()
    }

    func load() async {
        do {
            stations = try await service.getStations()

            objectWillChange.send()

            // Ensure any favorites from previous sessions are still valid
            favoriteStationIDs = favoriteStationIDs.filter { id in
                stations.contains { $0.id == id }
            }
        } catch {
            print("❌ Failed to load stations:", error)
        }
    }
}
extension StationStorage {

    var playableStations: [Station] {
        favoriteStations.isEmpty ? stations : favoriteStations
    }

    func nextStation(from current: Station?) -> Station? {
        guard let current,
              let index = playableStations.firstIndex(of: current)
        else {
            return playableStations.first
        }

        let nextIndex = (index + 1) % playableStations.count
        return playableStations[nextIndex]
    }

    func previousStation(from current: Station?) -> Station? {
        guard let current,
              let index = playableStations.firstIndex(of: current)
        else {
            return playableStations.first
        }

        let prevIndex = (index - 1 + playableStations.count) % playableStations.count
        return playableStations[prevIndex]
    }
}
