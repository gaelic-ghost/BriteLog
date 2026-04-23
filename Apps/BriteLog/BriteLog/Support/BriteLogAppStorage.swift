import Foundation

struct BriteLogAppStorage {
    private struct ProjectInstallDocument: Codable, Equatable {
        var installs: [BriteLogProjectInstall]
    }

    nonisolated static let defaultApplicationIdentifier = "com.gaelic-ghost.BriteLog"

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

    var currentRunRequestURL: URL {
        applicationSupportDirectory.appendingPathComponent("current-run-request.json")
    }

    var incomingRunRequestURL: URL {
        applicationSupportDirectory.appendingPathComponent("incoming-run-request.env")
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

    private static func parseIncomingRunRequest(from data: Data) throws -> BriteLogRunRequest {
        guard let text = String(data: data, encoding: .utf8) else {
            throw BriteLogAppStorageError(
                """
                BriteLog found an incoming run-request file, but it is not valid UTF-8 text.
                """,
            )
        }

        var values: [String: String] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            guard let separatorIndex = rawLine.firstIndex(of: "=") else {
                continue
            }

            let key = String(rawLine[..<separatorIndex])
            let value = String(rawLine[rawLine.index(after: separatorIndex)...])
            values[key] = value
        }

        let requestID = try parseUUID(
            values["requestID"],
            context: "BriteLog could not read `requestID` from the incoming run-request file.",
        )
        let submittedAt = try parseDate(
            values["submittedAt"],
            context: "BriteLog could not read `submittedAt` from the incoming run-request file.",
        )
        let source = try parseSource(
            values["source"],
            context: "BriteLog could not read `source` from the incoming run-request file.",
        )

        return try BriteLogRunRequest(
            id: requestID,
            submittedAt: submittedAt,
            projectPath: decodeRequiredValue(
                values: values,
                key: "projectPath",
                context: "BriteLog could not read `projectPath` from the incoming run-request file.",
            ),
            schemeName: decodeRequiredValue(
                values: values,
                key: "schemeName",
                context: "BriteLog could not read `schemeName` from the incoming run-request file.",
            ),
            targetName: decodeOptionalValue(values: values, key: "targetName"),
            bundleIdentifier: decodeRequiredValue(
                values: values,
                key: "bundleIdentifier",
                context: "BriteLog could not read `bundleIdentifier` from the incoming run-request file.",
            ),
            buildConfiguration: decodeRequiredValue(
                values: values,
                key: "buildConfiguration",
                context: "BriteLog could not read `buildConfiguration` from the incoming run-request file.",
            ),
            builtProductPath: decodeOptionalValue(values: values, key: "builtProductPath"),
            source: source,
        )
    }

    private static func parseUUID(
        _ rawValue: String?,
        context: String,
    ) throws -> UUID {
        guard let rawValue, let uuid = UUID(uuidString: rawValue) else {
            throw BriteLogAppStorageError(context)
        }

        return uuid
    }

    private static func parseDate(
        _ rawValue: String?,
        context: String,
    ) throws -> Date {
        let formatter = ISO8601DateFormatter()
        guard let rawValue, let date = formatter.date(from: rawValue) else {
            throw BriteLogAppStorageError(context)
        }

        return date
    }

    private static func parseSource(
        _ rawValue: String?,
        context: String,
    ) throws -> BriteLogRunRequest.Source {
        guard let rawValue, let source = BriteLogRunRequest.Source(rawValue: rawValue) else {
            throw BriteLogAppStorageError(context)
        }

        return source
    }

    private static func decodeRequiredValue(
        values: [String: String],
        key: String,
        context: String,
    ) throws -> String {
        guard let value = try decodeOptionalValue(values: values, key: key), !value.isEmpty else {
            throw BriteLogAppStorageError(context)
        }

        return value
    }

    private static func decodeOptionalValue(
        values: [String: String],
        key: String,
    ) throws -> String? {
        if let rawValue = values[key] {
            return rawValue.isEmpty ? nil : rawValue
        }

        guard let encodedValue = values["\(key)_b64"] else {
            return nil
        }
        guard let data = Data(base64Encoded: encodedValue), let decoded = String(data: data, encoding: .utf8) else {
            throw BriteLogAppStorageError(
                """
                BriteLog could not decode the base64-encoded `\(key)` value from the incoming run-request file.
                """,
            )
        }

        return decoded.isEmpty ? nil : decoded
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

    func loadCurrentRunRequest() throws -> BriteLogRunRequest? {
        guard fileManager.fileExists(atPath: currentRunRequestURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: currentRunRequestURL)
        return try JSONDecoder().decode(BriteLogRunRequest.self, from: data)
    }

    func saveCurrentRunRequest(_ request: BriteLogRunRequest?) throws {
        try ensureApplicationSupportDirectoryExists()

        guard let request else {
            if fileManager.fileExists(atPath: currentRunRequestURL.path) {
                try fileManager.removeItem(at: currentRunRequestURL)
            }
            return
        }

        let data = try Self.prettyJSONEncoder.encode(request)
        try data.write(to: currentRunRequestURL, options: [.atomic])
    }

    func consumeIncomingRunRequest() throws -> BriteLogRunRequest? {
        guard fileManager.fileExists(atPath: incomingRunRequestURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: incomingRunRequestURL)
        let request = try Self.parseIncomingRunRequest(from: data)
        try fileManager.removeItem(at: incomingRunRequestURL)
        return request
    }

    private func ensureApplicationSupportDirectoryExists() throws {
        try fileManager.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true,
        )
    }
}

private struct BriteLogAppStorageError: LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
