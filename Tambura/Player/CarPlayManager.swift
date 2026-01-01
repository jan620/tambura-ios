import CarPlay
import UIKit
import SwiftUI

@MainActor
final class CarPlayManager: NSObject {

    static let shared = CarPlayManager()
    private override init() {} // singleton

    private weak var interfaceController: CPInterfaceController?
    private var storage: StationStorage?
    private let nowPlayingTemplate = CPNowPlayingTemplate.shared

    // Keep track of the root template
    private var rootTemplate: CPListTemplate?

    // MARK: - Configure with storage
    func configure(with storage: StationStorage) {
        self.storage = storage
    }

    // MARK: - Connect / Disconnect
    func connect(_ controller: CPInterfaceController) {
        interfaceController = controller
        buildRootTemplate()
    }



    func disconnect() {
        interfaceController = nil
        rootTemplate = nil
    }

    // MARK: - Build Root Template
    private func buildRootTemplate() {
        guard let storage else { return }

        // Create CPListItems for each station
        let items: [CPListItem] = storage.stations.map { station in
            let item = CPListItem(text: station.name, detailText: station.desc)

            item.handler = { [weak self] _, completion in
                RadioPlayer.shared.play(station: station)
                storage.selectedStation = station

                self?.interfaceController?.presentTemplate(
                    CPNowPlayingTemplate.shared,
                    animated: true
                )

                completion()
            }

            return item
        }

        // Root list template
        let listTemplate = CPListTemplate(title: "Tambura", sections: [CPListSection(items: items)])
        listTemplate.delegate = self

        rootTemplate = listTemplate

        // Set the root template
        interfaceController?.setRootTemplate(listTemplate, animated: true)
    }
}

// MARK: - CPListTemplateDelegate
extension CarPlayManager: CPListTemplateDelegate {
    func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, completionHandler: @escaping () -> Void) {
        // Already handled in the CPListItem handler
        completionHandler()
    }
}

