import Foundation

struct Config: Codable {
    var anthropic_api_key: String?
}

enum ConfigManager {
    static func load() -> Config {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/recorder/config.json")
        guard let data = try? Data(contentsOf: path),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return Config() }
        return config
    }

    static var apiKey: String? {
        load().anthropic_api_key?.trimmingCharacters(in: .whitespaces).nonEmpty
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
