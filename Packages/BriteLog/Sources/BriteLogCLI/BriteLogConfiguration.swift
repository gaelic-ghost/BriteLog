import ArgumentParser
import Foundation

struct BriteLogConfiguration: Codable, Equatable {
    var selectedTheme: BriteLogCommand.Theme?
}

struct BriteLogConfigurationStore {
    var fileManager: FileManager
    var configURL: URL
    var legacyConfigURL: URL

    init(
        fileManager: FileManager = .default,
        configURL: URL? = nil,
        legacyConfigURL: URL? = nil,
    ) {
        self.fileManager = fileManager
        self.configURL = configURL ?? Self.defaultConfigURL(fileManager: fileManager)
        self.legacyConfigURL = legacyConfigURL ?? Self.legacyConfigURL(fileManager: fileManager)
    }

    static func defaultConfigURL(fileManager: FileManager) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("gaelic-ghost", isDirectory: true)
            .appendingPathComponent("britelog", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    static func legacyConfigURL(fileManager: FileManager) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("britelog", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    func load() throws -> BriteLogConfiguration {
        guard fileManager.fileExists(atPath: configURL.path) else {
            guard fileManager.fileExists(atPath: legacyConfigURL.path) else {
                return .init(selectedTheme: nil)
            }

            let legacyData = try Data(contentsOf: legacyConfigURL)
            return try JSONDecoder().decode(BriteLogConfiguration.self, from: legacyData)
        }

        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(BriteLogConfiguration.self, from: data)
    }

    func save(_ configuration: BriteLogConfiguration) throws {
        let directoryURL = configURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(configuration)
        try data.write(to: configURL, options: .atomic)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension BriteLogCommand.Theme {
    var displayName: String {
        switch self {
            case .xcode:
                "Xcode"
            case .neon:
                "Neon"
            case .plain:
                "Plain"
        }
    }

    var summary: String {
        switch self {
            case .xcode:
                "Balanced IDE-style colors for everyday debugging."
            case .neon:
                "Higher-contrast terminal colors with a brighter cyber look."
            case .plain:
                "No ANSI colors, just readable structured text."
        }
    }
}
