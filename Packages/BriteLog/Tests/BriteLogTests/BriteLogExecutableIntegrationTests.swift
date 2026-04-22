@testable import BriteLogCLI
import Foundation
import Testing

private enum BriteLogExecutableIntegrationSupport {
    struct ProcessResult {
        var status: Int32
        var stdout: String
        var stderr: String
    }

    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func locateBuiltExecutable(named name: String) throws -> URL {
        let buildRoot = packageRoot.appendingPathComponent(".build", isDirectory: true)
        let enumerator = FileManager.default.enumerator(
            at: buildRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isExecutableKey],
            options: [.skipsHiddenFiles],
        )

        var matches: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.lastPathComponent == name else {
                continue
            }

            let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isExecutableKey])
            guard values.isRegularFile == true, values.isExecutable == true else {
                continue
            }

            matches.append(item)
        }

        guard let bestMatch = matches.sorted(by: { score(runsBefore: $0, $1) }).first else {
            throw TestSupportError("Could not find a built executable named \(name) under \(buildRoot.path).")
        }

        return bestMatch
    }

    static func runExecutable(
        at executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:],
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stdoutText = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderrText = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        return ProcessResult(
            status: process.terminationStatus,
            stdout: stdoutText,
            stderr: stderrText,
        )
    }

    private static func score(runsBefore lhs: URL, _ rhs: URL) -> Bool {
        let lhsPath = lhs.path
        let rhsPath = rhs.path
        let lhsDebug = lhsPath.contains("/debug/")
        let rhsDebug = rhsPath.contains("/debug/")

        if lhsDebug != rhsDebug {
            return lhsDebug
        }

        return lhsPath.count < rhsPath.count
    }
}

private struct TestSupportError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}

@Test func `built swiftpm executable prints the watch intro when no focus is provided`() throws {
    let executableURL = try BriteLogExecutableIntegrationSupport.locateBuiltExecutable(named: "BriteLog")
    let result = try BriteLogExecutableIntegrationSupport.runExecutable(
        at: executableURL,
        arguments: ["watch"],
    )

    #expect(result.status == 0)
    #expect(result.stdout == BriteLogCommand.Watch.introText + "\n")
    #expect(result.stderr.isEmpty)
}

@Test func `built swiftpm executable stores selected theme under the namespaced config path`() throws {
    let executableURL = try BriteLogExecutableIntegrationSupport.locateBuiltExecutable(named: "BriteLog")
    let temporaryRoot = FileManager.default
        .temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configRoot = temporaryRoot.appendingPathComponent(".config", isDirectory: true)
    try FileManager.default.createDirectory(at: configRoot, withIntermediateDirectories: true)

    let selectResult = try BriteLogExecutableIntegrationSupport.runExecutable(
        at: executableURL,
        arguments: ["themes", "select", "aurora"],
        environment: ["XDG_CONFIG_HOME": configRoot.path],
    )
    let listResult = try BriteLogExecutableIntegrationSupport.runExecutable(
        at: executableURL,
        arguments: ["themes", "list"],
        environment: ["XDG_CONFIG_HOME": configRoot.path],
    )

    let configURL = configRoot
        .appendingPathComponent("gaelic-ghost", isDirectory: true)
        .appendingPathComponent("britelog", isDirectory: true)
        .appendingPathComponent("config.json")

    let savedConfiguration = try JSONDecoder().decode(
        BriteLogConfiguration.self,
        from: Data(contentsOf: configURL),
    )

    #expect(selectResult.status == 0)
    #expect(selectResult.stdout.contains("Saved BriteLog default theme: aurora"))
    #expect(listResult.status == 0)
    #expect(listResult.stdout.contains("* aurora - Aurora (current default)"))
    #expect(savedConfiguration.selectedTheme == .aurora)
}
