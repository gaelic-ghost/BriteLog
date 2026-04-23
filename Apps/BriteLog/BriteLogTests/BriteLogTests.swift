@testable import BriteLog
import BriteLogCore
import Foundation
import Testing

@MainActor
struct BriteLogTests {
    @Test
    func `app entry point compiles`() {
        _ = BriteLogApp.self
    }

    @Test
    func `app storage returns defaults when files are missing`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)

        #expect(try storage.loadConfiguration() == .default)
        #expect(try storage.loadProjectInstalls().isEmpty)
    }

    @Test
    func `app storage round trips configuration and project installs`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        let configuration = BriteLogAppConfiguration(selectedTheme: .aurora, showViewerOnLaunch: false)
        let installs = [
            BriteLogProjectInstall(
                displayName: "Example App",
                projectPath: "/tmp/ExampleApp",
                schemeName: "ExampleApp",
                integrationKind: .buildPlugin,
                notes: "Created for test coverage.",
            ),
        ]

        try storage.saveConfiguration(configuration)
        try storage.saveProjectInstalls(installs)

        #expect(try storage.loadConfiguration() == configuration)
        #expect(try storage.loadProjectInstalls() == installs)
    }
}
