import Foundation
import ArgumentParser

struct ThisAppBundleIdentifierResolver {
    struct BuildSettingsEntry: Equatable {
        var target: String?
        var buildSettings: [String: String]
    }

    typealias CommandRunner = (_ arguments: [String]) throws -> Data

    var currentDirectoryPath: String
    var commandRunner: CommandRunner
    var fileManager: FileManager

    init(
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        commandRunner: @escaping CommandRunner = Self.defaultCommandRunner,
        fileManager: FileManager = .default
    ) {
        self.currentDirectoryPath = currentDirectoryPath
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    func resolve() throws -> String {
        let projectURL = try resolveProjectURL()
        let scheme = try resolveScheme(projectURL: projectURL)
        let entries = try resolveBuildSettings(projectURL: projectURL, scheme: scheme)
        return try Self.chooseBundleIdentifier(
            entries: entries,
            preferredName: scheme,
            projectName: projectURL.deletingPathExtension().lastPathComponent
        )
    }

    private func resolveProjectURL() throws -> URL {
        let directoryURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let projects = urls
            .filter { $0.pathExtension == "xcodeproj" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !projects.isEmpty else {
            throw ValidationError(
                """
                `--this-app` expects the current directory to contain exactly one `.xcodeproj`, but none were found in
                `\(currentDirectoryPath)`.
                """
            )
        }
        guard projects.count == 1 else {
            let names = projects.map(\.lastPathComponent).joined(separator: ", ")
            throw ValidationError(
                """
                `--this-app` expects the current directory to contain exactly one `.xcodeproj`, but found multiple:
                \(names)
                """
            )
        }

        return projects[0]
    }

    private func resolveScheme(projectURL: URL) throws -> String {
        let data = try commandRunner(["xcodebuild", "-list", "-project", projectURL.path, "-json"])
        let schemes = try Self.parseSchemes(from: data)
        return try Self.chooseScheme(
            schemes: schemes,
            projectName: projectURL.deletingPathExtension().lastPathComponent
        )
    }

    private func resolveBuildSettings(
        projectURL: URL,
        scheme: String
    ) throws -> [BuildSettingsEntry] {
        let data = try commandRunner([
            "xcodebuild",
            "-project", projectURL.path,
            "-scheme", scheme,
            "-showBuildSettings",
            "-json",
        ])
        return try Self.parseBuildSettingsEntries(from: data)
    }

    private static func defaultCommandRunner(arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ValidationError(
                """
                `--this-app` could not query Xcode for bundle information.
                Command: \(arguments.joined(separator: " "))
                \(message?.isEmpty == false ? message! : "xcodebuild exited with status \(process.terminationStatus).")
                """
            )
        }

        return output
    }

    static func parseSchemes(from data: Data) throws -> [String] {
        struct Payload: Decodable {
            struct Project: Decodable {
                var schemes: [String]?
            }

            var project: Project?
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.project?.schemes ?? []
    }

    static func chooseScheme(
        schemes: [String],
        projectName: String
    ) throws -> String {
        guard !schemes.isEmpty else {
            throw ValidationError(
                """
                `--this-app` could not find any shared schemes in the current Xcode project.
                """
            )
        }
        if schemes.contains(projectName) {
            return projectName
        }
        if schemes.count == 1, let scheme = schemes.first {
            return scheme
        }

        throw ValidationError(
            """
            `--this-app` found multiple schemes and could not infer which app to inspect.
            Project name: \(projectName)
            Schemes: \(schemes.joined(separator: ", "))
            """
        )
    }

    static func parseBuildSettingsEntries(from data: Data) throws -> [BuildSettingsEntry] {
        struct PayloadEntry: Decodable {
            var target: String?
            var buildSettings: [String: String]
        }

        let decoded = try JSONDecoder().decode([PayloadEntry].self, from: data)
        return decoded.map { BuildSettingsEntry(target: $0.target, buildSettings: $0.buildSettings) }
    }

    static func chooseBundleIdentifier(
        entries: [BuildSettingsEntry],
        preferredName: String,
        projectName: String
    ) throws -> String {
        let candidates = entries.filter {
            guard let bundleID = $0.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"], !bundleID.isEmpty else {
                return false
            }
            return true
        }

        let appCandidates = candidates.filter { entry in
            entry.buildSettings["WRAPPER_EXTENSION"] == "app"
        }

        let narrowed = appCandidates.isEmpty ? candidates : appCandidates
        guard !narrowed.isEmpty else {
            throw ValidationError(
                """
                `--this-app` could not find an app target with a `PRODUCT_BUNDLE_IDENTIFIER` in the current Xcode project.
                """
            )
        }

        if let exact = narrowed.first(where: { $0.target == preferredName || $0.target == projectName }) {
            return exact.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]!
        }
        if narrowed.count == 1, let only = narrowed.first {
            return only.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"]!
        }

        let names = narrowed.map { $0.target ?? "<unnamed target>" }.joined(separator: ", ")
        throw ValidationError(
            """
            `--this-app` found multiple candidate app targets and could not infer which bundle identifier to use.
            Targets: \(names)
            """
        )
    }
}
