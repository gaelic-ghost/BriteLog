import Foundation

struct BriteLogAppStorage {
    private struct ProjectInstallDocument: Codable, Equatable {
        var installs: [BriteLogProjectInstall]
    }

    static let defaultApplicationIdentifier = "com.gaelic-ghost.BriteLog"

    private static var prettyJSONEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    var fileManager: FileManager
    var applicationIdentifier: String
    var applicationSupportDirectory: URL

    var configurationURL: URL {
        applicationSupportDirectory.appendingPathComponent("app-config.json")
    }

    var projectInstallsURL: URL {
        applicationSupportDirectory.appendingPathComponent("project-installs.json")
    }

    init(
        fileManager: FileManager = .default,
        applicationIdentifier: String = Self.defaultApplicationIdentifier,
        applicationSupportDirectory: URL? = nil,
    ) {
        self.fileManager = fileManager
        self.applicationIdentifier = applicationIdentifier
        self.applicationSupportDirectory =
            applicationSupportDirectory
                ?? Self.defaultApplicationSupportDirectory(
                    fileManager: fileManager,
                    applicationIdentifier: applicationIdentifier,
                )
    }

    static func defaultApplicationSupportDirectory(
        fileManager: FileManager,
        applicationIdentifier: String,
    ) -> URL {
        let baseURL =
            try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true,
            )

        return (baseURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true))
            .appendingPathComponent(applicationIdentifier, isDirectory: true)
    }

    func loadConfiguration() throws -> BriteLogAppConfiguration {
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            return .default
        }

        let data = try Data(contentsOf: configurationURL)
        return try JSONDecoder().decode(BriteLogAppConfiguration.self, from: data)
    }

    func saveConfiguration(_ configuration: BriteLogAppConfiguration) throws {
        try ensureApplicationSupportDirectoryExists()
        let data = try Self.prettyJSONEncoder.encode(configuration)
        try data.write(to: configurationURL, options: [.atomic])
    }

    func loadProjectInstalls() throws -> [BriteLogProjectInstall] {
        guard fileManager.fileExists(atPath: projectInstallsURL.path) else {
            return []
        }

        let data = try Data(contentsOf: projectInstallsURL)
        return try JSONDecoder().decode(ProjectInstallDocument.self, from: data).installs
    }

    func saveProjectInstalls(_ installs: [BriteLogProjectInstall]) throws {
        try ensureApplicationSupportDirectoryExists()
        let document = ProjectInstallDocument(installs: installs)
        let data = try Self.prettyJSONEncoder.encode(document)
        try data.write(to: projectInstallsURL, options: [.atomic])
    }

    private func ensureApplicationSupportDirectoryExists() throws {
        try fileManager.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true,
        )
    }
}
