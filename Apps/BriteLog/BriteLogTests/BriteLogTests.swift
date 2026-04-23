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
        #expect(try storage.loadCurrentRunRequest() == nil)
    }

    @Test
    func `app storage round trips configuration installs and current request`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        let configuration = BriteLogAppConfiguration(selectedTheme: .aurora, showViewerOnLaunch: false)
        let installs = [
            BriteLogProjectInstall(
                displayName: "Example App",
                projectPath: "/tmp/ExampleApp",
                schemeName: "ExampleApp",
                bundleIdentifier: "com.example.ExampleApp",
                integrationKind: .buildPlugin,
                notes: "Created for test coverage.",
            ),
        ]
        let currentRunRequest = BriteLogRunRequest(
            projectPath: "/tmp/ExampleApp/ExampleApp.xcodeproj",
            schemeName: "ExampleApp",
            targetName: "ExampleApp",
            bundleIdentifier: "com.example.ExampleApp",
            buildConfiguration: "Debug",
            builtProductPath: "/tmp/DerivedData/Debug/ExampleApp.app",
            source: .schemePreAction,
        )

        try storage.saveConfiguration(configuration)
        try storage.saveProjectInstalls(installs)
        try storage.saveCurrentRunRequest(currentRunRequest)

        #expect(try storage.loadConfiguration() == configuration)
        #expect(try storage.loadProjectInstalls() == installs)
        #expect(try storage.loadCurrentRunRequest() == currentRunRequest)
    }

    @Test
    func `incoming run request env file is consumed into a structured request`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let requestID = try #require(UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000"))
        let requestContents = """
        requestID=\(requestID.uuidString)
        submittedAt=2026-04-22T23:15:04Z
        source=schemePreAction
        projectPath_b64=\(Data("/tmp/ExampleApp/ExampleApp.xcodeproj".utf8).base64EncodedString())
        schemeName_b64=\(Data("ExampleApp".utf8).base64EncodedString())
        targetName_b64=\(Data("ExampleApp".utf8).base64EncodedString())
        bundleIdentifier_b64=\(Data("com.example.ExampleApp".utf8).base64EncodedString())
        buildConfiguration_b64=\(Data("Debug".utf8).base64EncodedString())
        builtProductPath_b64=\(Data("/tmp/DerivedData/Debug/ExampleApp.app".utf8).base64EncodedString())
        """

        let requestData = try #require(requestContents.data(using: .utf8))
        try requestData.write(to: storage.incomingRunRequestURL)
        let request = try storage.consumeIncomingRunRequest()

        #expect(request?.id == requestID)
        #expect(request?.schemeName == "ExampleApp")
        #expect(request?.bundleIdentifier == "com.example.ExampleApp")
        #expect(request?.source == .schemePreAction)
        #expect(FileManager.default.fileExists(atPath: storage.incomingRunRequestURL.path) == false)
    }

    @Test
    func `scheme pre action installer injects a named launch pre action`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectURL = root.appendingPathComponent("ExampleApp.xcodeproj", isDirectory: true)
        let schemeDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
        let schemeURL = schemeDirectory.appendingPathComponent("ExampleApp.xcscheme")
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)

        let schemeXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme LastUpgradeVersion="2620" version="1.7">
          <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
            <BuildActionEntries>
              <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
                <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="ABC123" BuildableName="ExampleApp.app" BlueprintName="ExampleApp" ReferencedContainer="container:ExampleApp.xcodeproj">
                </BuildableReference>
              </BuildActionEntry>
            </BuildActionEntries>
          </BuildAction>
          <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB">
            <BuildableProductRunnable runnableDebuggingMode="0">
              <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="ABC123" BuildableName="ExampleApp.app" BlueprintName="ExampleApp" ReferencedContainer="container:ExampleApp.xcodeproj">
              </BuildableReference>
            </BuildableProductRunnable>
          </LaunchAction>
        </Scheme>
        """

        let schemeData = try #require(schemeXML.data(using: .utf8))
        try schemeData.write(to: schemeURL)

        let installer = BriteLogSchemePreActionInstaller(
            inspector: BriteLogXcodeProjectInspector(),
        )
        _ = try installer.install(
            projectURL: projectURL,
            appTarget: BriteLogXcodeResolvedAppTarget(
                schemeName: "ExampleApp",
                targetName: "ExampleApp",
                bundleIdentifier: "com.example.ExampleApp",
            ),
        )

        let installedXML = try String(contentsOf: schemeURL)
        #expect(installedXML.contains("Use BriteLog For Debug Runs"))
        #expect(installedXML.contains("incoming-run-request.env"))
        #expect(installedXML.contains("schemePreAction"))
        #expect(installedXML.contains("com.galewilliams.BriteLog"))
    }
}
