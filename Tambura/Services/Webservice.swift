import Foundation

enum NetworkError: Error {
    case badUrl
    case badResponse
    case decodingError
}

final class Webservice {

    private let urlString = "https://yogi-tech.de/app.radioplayer/stations.json"

    func getStations() async throws -> [Station] {
        guard let url = URL(string: urlString) else {
            throw NetworkError.badUrl
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NetworkError.badResponse
        }

        do {
            let decoded = try JSONDecoder().decode(StationList.self, from: data)
            return decoded.station
        } catch {
            print("❌ JSON decoding failed:", error)
            throw NetworkError.decodingError
        }
    }
}
