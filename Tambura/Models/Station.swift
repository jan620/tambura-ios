import Foundation

struct StationList: Codable {
    let station: [Station]
}

struct Station: Identifiable, Codable, Hashable {
    let id: String
    let type: String
    let name: String
    let streamURL: String
    let imageURL: String
    let desc: String
    let country: String?
    let theme: Theme

    enum CodingKeys: String, CodingKey {
        case id, name, type, streamURL, imageURL, desc, country, theme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        streamURL = try container.decode(String.self, forKey: .streamURL)
        imageURL = try container.decode(String.self, forKey: .imageURL)
        desc = try container.decode(String.self, forKey: .desc)
        country = try container.decode(String.self, forKey: .country)
        theme = try container.decode(Theme.self, forKey: .theme)
    }
}


struct Theme: Codable, Hashable {
    let firstColor: String
    let secondColor: String
    let thirdColor: String
}
