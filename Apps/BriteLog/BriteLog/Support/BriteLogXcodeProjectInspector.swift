import Foundation

struct BriteLogXcodeProjectInspection: Equatable {
    var projectURL: URL
    var projectName: String
    var schemes: [String]
    var preferredScheme: String
}

struct BriteLogXcodeResolvedAppTarget: Equatable {
    var schemeName: String
    var targetName: String?
    var bundleIdentifier: String
}

struct BriteLogXcodeProjectInspector {
    struct BuildSettingsEntry: Equatable {
        var target: String?
        var buildSettings: [String: String]
    }

    typealias CommandRunner = @Sendable (_ arguments: [String]) throws -> Data

    var commandRunner: CommandRunner

    nonisolated init(commandRunner: @escaping CommandRunner = Self.defaultCommandRunner) {
        self.commandRunner = commandRunner
    }

    nonisolated static func requireProjectURL(_ projectURL: URL) throws {
        guard projectURL.pathExtension == "xcodeproj" else {
            throw BriteLogXcodeProjectInspectorError(
                """
                BriteLog expected an `.xcodeproj`, but received:
                \(projectURL.path)
                """,
            )
        }
    }

    nonisolated static func choosePreferredScheme(
        schemes: [String],
        projectName: String,
    ) throws -> String {
        guard !schemes.isEmpty else {
            throw BriteLogXcodeProjectInspectorError(
                """
                BriteLog could not find any shared schemes in the selected Xcode project.
                Share a scheme in Xcode first, then try again.
                """,
            )
        }

        if schemes.contains(projectName) {
            return projectName
        }
        if schemes.count == 1, let onlyScheme = schemes.first {
            return onlyScheme
        }

        return schemes[0]
    }

    nonisolated static func parseSchemes(from data: Data) throws -> [String] {
        struct Payload: Decodable {
            struct Project: Decodable {
                var schemes: [String]?
            }

            var project: Project?
        }

        return try JSONDecoder().decode(Payload.self, from: data).project?.schemes ?? []
    }

    nonisolated static func parseBuildSettingsEntries(from data: Data) throws -> [BuildSettingsEntry] {
        struct PayloadEntry: Decodable {
            var target: String?
            var buildSettings: [String: String]
        }

        return try JSONDecoder()
            .decode([PayloadEntry].self, from: data)
            .map { BuildSettingsEntry(target: $0.target, buildSettings: $0.buildSettings) }
    }

    nonisolated static func chooseAppTarget(
        entries: [BuildSettingsEntry],
        preferredName: String,
        projectName: String,
    ) throws -> BuildSettingsEntry {
        let bundleCandidates = entries.filter {
            guard let bundleIdentifier = $0.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] else {
                return false
            }

            return !bundleIdentifier.isEmpty
        }

        let appCandidates = bundleCandidates.filter { $0.buildSettings["WRAPPER_EXTENSION"] == "app" }
        let narrowed = appCandidates.isEmpty ? bundleCandidates : appCandidates

        guard !narrowed.isEmpty else {
            throw BriteLogXcodeProjectInspectorError(
                """
                BriteLog could not find an app target with a bundle identifier in the selected Xcode project.
                Scheme: \(preferredName)
                """,
            )
        }

        if let exact = narrowed.first(where: { $0.target == preferredName || $0.target == projectName }) {
            return exact
        }
        if narrowed.count == 1, let only = narrowed.first {
            return only
        }

        let names = narrowed.map { $0.target ?? "<unnamed target>" }.joined(separator: ", ")
        throw BriteLogXcodeProjectInspectorError(
            """
            BriteLog found multiple app targets for the selected scheme and could not infer which one should drive log targeting.
            Scheme: \(preferredName)
            Candidate targets: \(names)
            """,
        )
    }

    private nonisolated static func defaultCommandRunner(arguments: [String]) throws -> Data {
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
            let diagnostic = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let failureDescription = if let diagnostic, !diagnostic.isEmpty {
                diagnostic
            } else {
                "xcodebuild exited with status \(process.terminationStatus)."
            }
            throw BriteLogXcodeProjectInspectorError(
                """
                BriteLog could not query Xcode for project details.
                Command: \(arguments.joined(separator: " "))
                \(failureDescription)
                """,
            )
        }

        return output
    }

    nonisolated func inspectProject(at projectURL: URL) throws -> BriteLogXcodeProjectInspection {
        try Self.requireProjectURL(projectURL)
        let schemes = try resolveSchemes(projectURL: projectURL)
        let projectName = projectURL.deletingPathExtension().lastPathComponent
        let preferredScheme = try Self.choosePreferredScheme(
            schemes: schemes,
            projectName: projectName,
        )

        return BriteLogXcodeProjectInspection(
            projectURL: projectURL,
            projectName: projectName,
            schemes: schemes,
            preferredScheme: preferredScheme,
        )
    }

    nonisolated func resolveAppTarget(
        projectURL: URL,
        schemeName: String,
    ) throws -> BriteLogXcodeResolvedAppTarget {
        let entries = try resolveBuildSettings(projectURL: projectURL, schemeName: schemeName)
        let entry = try Self.chooseAppTarget(
            entries: entries,
            preferredName: schemeName,
            projectName: projectURL.deletingPathExtension().lastPathComponent,
        )

        guard let bundleIdentifier = entry.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"], !bundleIdentifier.isEmpty else {
            throw BriteLogXcodeProjectInspectorError(
                """
                BriteLog could not resolve `PRODUCT_BUNDLE_IDENTIFIER` for the selected scheme.
                Scheme: \(schemeName)
                Target: \(entry.target ?? "<unnamed target>")
                """,
            )
        }

        return BriteLogXcodeResolvedAppTarget(
            schemeName: schemeName,
            targetName: entry.target,
            bundleIdentifier: bundleIdentifier,
        )
    }

    nonisolated func sharedSchemeURL(
        projectURL: URL,
        schemeName: String,
    ) -> URL {
        projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
            .appendingPathComponent("\(schemeName).xcscheme")
    }

    private nonisolated func resolveSchemes(projectURL: URL) throws -> [String] {
        let data = try commandRunner(["xcodebuild", "-list", "-project", projectURL.path, "-json"])
        return try Self.parseSchemes(from: data)
    }

    private nonisolated func resolveBuildSettings(
        projectURL: URL,
        schemeName: String,
    ) throws -> [BuildSettingsEntry] {
        let data = try commandRunner([
            "xcodebuild",
            "-project", projectURL.path,
            "-scheme", schemeName,
            "-showBuildSettings",
            "-json",
        ])
        return try Self.parseBuildSettingsEntries(from: data)
    }
}

private struct BriteLogXcodeProjectInspectorError: LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
