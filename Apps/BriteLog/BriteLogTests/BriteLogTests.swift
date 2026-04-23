@testable import BriteLog
import BriteLogCore
import Foundation
import Testing

@MainActor
struct BriteLogTests {
    private let resolvedAppTarget = BriteLogXcodeResolvedAppTarget(
        schemeName: "ExampleApp",
        targetName: "ExampleApp",
        bundleIdentifier: "com.example.ExampleApp",
    )

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
        let configuration = BriteLogAppConfiguration(
            selectedTheme: .aurora,
            showViewerOnLaunch: false,
            viewerPreferences: BriteLogViewerPreferences(
                searchText: "network",
                highlightText: "error",
                minimumLevel: .warning,
                metadataMode: .full,
            ),
        )
        let installs = [
            BriteLogProjectInstall(
                displayName: "Example App",
                projectPath: "/tmp/ExampleApp",
                schemeName: "ExampleApp",
                bundleIdentifier: "com.example.ExampleApp",
                schemePath: "/tmp/ExampleApp/ExampleApp.xcodeproj/xcshareddata/xcschemes/ExampleApp.xcscheme",
                schemeFingerprint: "abc123",
                backupPath: "/tmp/BriteLogBackups/ExampleApp.xcscheme",
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
    func `app model starts with an idle viewer session when there is no run request`() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        let model = BriteLogAppModel(
            storage: storage,
            runningApplicationsProvider: { [] },
            shouldStartSystemIntegration: false,
        )

        #expect(model.currentRunRequest == nil)
        #expect(model.viewerSession.state == .idle)
        #expect(model.viewerSession.request == nil)
        #expect(model.viewerSession.observedApplication == nil)
    }

    @Test
    func `app model opens a waiting viewer session when a run request arrives before launch`() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        let request = BriteLogRunRequest(
            projectPath: "/tmp/ExampleApp/ExampleApp.xcodeproj",
            schemeName: "ExampleApp",
            targetName: "ExampleApp",
            bundleIdentifier: "com.example.ExampleApp",
            buildConfiguration: "Debug",
            builtProductPath: "/tmp/DerivedData/Debug/ExampleApp.app",
            source: .schemePreAction,
        )
        let model = BriteLogAppModel(
            storage: storage,
            runningApplicationsProvider: { [] },
            shouldStartSystemIntegration: false,
        )

        model.applyRunRequest(request)

        #expect(model.currentRunRequest == request)
        #expect(model.viewerSession.state == .waitingForLaunch)
        #expect(model.viewerSession.request == request)
        #expect(model.viewerSession.observedApplication?.phase == .waitingForLaunch)
    }

    @Test
    func `app model attaches and ends the viewer session for matching workspace events`() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        let request = BriteLogRunRequest(
            projectPath: "/tmp/ExampleApp/ExampleApp.xcodeproj",
            schemeName: "ExampleApp",
            targetName: "ExampleApp",
            bundleIdentifier: "com.example.ExampleApp",
            buildConfiguration: "Debug",
            builtProductPath: "/tmp/DerivedData/Debug/ExampleApp.app",
            source: .schemePreAction,
        )
        let model = BriteLogAppModel(
            storage: storage,
            runningApplicationsProvider: { [] },
            shouldStartSystemIntegration: false,
        )

        model.applyRunRequest(request)
        model.applyWorkspaceApplicationEvent(
            bundleIdentifier: "com.example.ExampleApp",
            localizedName: "Example App",
            processIdentifier: 4242,
            phase: .running,
        )

        #expect(model.viewerSession.state == .attached)
        #expect(model.viewerSession.observedApplication?.processIdentifier == 4242)
        #expect(model.viewerSession.endedAt == nil)

        model.applyWorkspaceApplicationEvent(
            bundleIdentifier: "com.example.ExampleApp",
            localizedName: "Example App",
            processIdentifier: 4242,
            phase: .terminated,
        )

        #expect(model.viewerSession.state == .ended)
        #expect(model.viewerSession.observedApplication?.phase == .terminated)
        #expect(model.viewerSession.endedAt != nil)
    }

    @Test
    func `viewer session buffers records for the active run request`() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        let request = BriteLogRunRequest(
            projectPath: "/tmp/ExampleApp/ExampleApp.xcodeproj",
            schemeName: "ExampleApp",
            targetName: "ExampleApp",
            bundleIdentifier: "com.example.ExampleApp",
            buildConfiguration: "Debug",
            builtProductPath: "/tmp/DerivedData/Debug/ExampleApp.app",
            source: .schemePreAction,
        )
        let model = BriteLogAppModel(
            storage: storage,
            runningApplicationsProvider: { [] },
            shouldStartSystemIntegration: false,
        )
        let records = [
            BriteLogRecord(
                date: .now,
                level: .info,
                subsystem: "com.example.ExampleApp",
                category: "launch",
                process: "ExampleApp",
                processIdentifier: 4242,
                sender: "ExampleApp",
                message: "Application booted",
            ),
            BriteLogRecord(
                date: .now.addingTimeInterval(1),
                level: .warning,
                subsystem: "com.example.ExampleApp",
                category: "startup",
                process: "ExampleApp",
                processIdentifier: 4242,
                sender: "ExampleApp",
                message: "Slow startup path engaged",
            ),
        ]

        model.applyRunRequest(request)
        model.appendViewerRecords(records)

        #expect(model.viewerSession.records == records)
        #expect(model.viewerSession.request == request)
    }

    @Test
    func `app model streams live records into the active viewer session`() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        let request = BriteLogRunRequest(
            projectPath: "/tmp/ExampleApp/ExampleApp.xcodeproj",
            schemeName: "ExampleApp",
            targetName: "ExampleApp",
            bundleIdentifier: "com.example.ExampleApp",
            buildConfiguration: "Debug",
            builtProductPath: "/tmp/DerivedData/Debug/ExampleApp.app",
            source: .schemePreAction,
        )
        let streamedRecords = [
            BriteLogRecord(
                date: .now,
                level: .info,
                subsystem: "com.example.ExampleApp",
                category: "launch",
                process: "ExampleApp",
                processIdentifier: 4242,
                sender: "ExampleApp",
                message: "Streaming boot record",
            ),
            BriteLogRecord(
                date: .now.addingTimeInterval(1),
                level: .notice,
                subsystem: "com.example.ExampleApp",
                category: "startup",
                process: "ExampleApp",
                processIdentifier: 4242,
                sender: "ExampleApp",
                message: "Streaming startup record",
            ),
        ]
        let model = BriteLogAppModel(
            storage: storage,
            runningApplicationsProvider: { [] },
            liveRecordSource: BriteLogViewerSessionLiveRecordSource { _ in
                AsyncThrowingStream { continuation in
                    for record in streamedRecords {
                        continuation.yield(record)
                    }
                    continuation.finish()
                }
            },
            shouldStartSystemIntegration: false,
        )

        model.applyRunRequest(request)

        for _ in 0..<20 where model.viewerSession.records.count < streamedRecords.count {
            await Task.yield()
        }

        #expect(model.viewerSession.records == streamedRecords)
        #expect(model.viewerSession.state == .waitingForLaunch)
    }

    @Test
    func `app model does not restart live streaming when the same session attaches`() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BriteLogAppStorage(applicationSupportDirectory: root)
        let request = BriteLogRunRequest(
            projectPath: "/tmp/ExampleApp/ExampleApp.xcodeproj",
            schemeName: "ExampleApp",
            targetName: "ExampleApp",
            bundleIdentifier: "com.example.ExampleApp",
            buildConfiguration: "Debug",
            builtProductPath: "/tmp/DerivedData/Debug/ExampleApp.app",
            source: .schemePreAction,
        )
        let invocationCounter = LockedCounter()
        let model = BriteLogAppModel(
            storage: storage,
            runningApplicationsProvider: { [] },
            liveRecordSource: BriteLogViewerSessionLiveRecordSource { _ in
                invocationCounter.increment()
                return AsyncThrowingStream { continuation in
                    continuation.finish()
                }
            },
            shouldStartSystemIntegration: false,
        )

        model.applyRunRequest(request)
        for _ in 0..<10 {
            await Task.yield()
        }

        model.applyWorkspaceApplicationEvent(
            bundleIdentifier: "com.example.ExampleApp",
            localizedName: "Example App",
            processIdentifier: 4242,
            phase: .running,
        )
        for _ in 0..<10 {
            await Task.yield()
        }

        #expect(invocationCounter.value == 1)
        #expect(model.viewerSession.state == .attached)
    }

    @Test
    func `viewer presentation filters highlights and formats rows from sticky preferences`() {
        let records = [
            BriteLogRecord(
                date: Date(timeIntervalSinceReferenceDate: 100),
                level: .info,
                subsystem: "com.example.ExampleApp",
                category: "launch",
                process: "ExampleApp",
                processIdentifier: 4242,
                sender: "ExampleApp",
                message: "Application booted cleanly",
            ),
            BriteLogRecord(
                date: Date(timeIntervalSinceReferenceDate: 101),
                level: .error,
                subsystem: "com.example.ExampleApp",
                category: "network",
                process: "ExampleApp",
                processIdentifier: 4242,
                sender: "Networking",
                message: "Network request failed hard",
            ),
        ]
        let preferences = BriteLogViewerPreferences(
            searchText: "network",
            highlightText: "failed",
            minimumLevel: .warning,
            metadataMode: .full,
        )

        let rows = BriteLogViewerPresentation.rows(from: records, preferences: preferences)

        #expect(rows.count == 1)
        #expect(rows[0].record.message == "Network request failed hard")
        #expect(rows[0].isHighlighted)
        #expect(rows[0].sourceText == "com.example.ExampleApp")
        #expect(rows[0].detailsText?.contains("network") == true)
    }

    @Test
    func `scheme pre action installer reports not installed before mutation`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectURL = root.appendingPathComponent("ExampleApp.xcodeproj", isDirectory: true)
        let schemeDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
        let schemeURL = schemeDirectory.appendingPathComponent("ExampleApp.xcscheme")
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)

        try makeBaseSchemeXML().write(to: schemeURL, atomically: true, encoding: .utf8)

        let installer = BriteLogSchemePreActionInstaller(
            inspector: BriteLogXcodeProjectInspector(),
            backupRootDirectory: root.appendingPathComponent("Backups", isDirectory: true),
            isXcodeRunning: { false },
        )

        let inspection = try installer.inspect(
            projectURL: projectURL,
            appTarget: resolvedAppTarget,
        )

        #expect(inspection.state == .notInstalled)
        #expect(inspection.canMutate)
        #expect(inspection.warnings.isEmpty)
    }

    @Test
    func `scheme pre action installer writes backup and reports installed state`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectURL = root.appendingPathComponent("ExampleApp.xcodeproj", isDirectory: true)
        let schemeDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
        let schemeURL = schemeDirectory.appendingPathComponent("ExampleApp.xcscheme")
        let backupDirectory = root.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)
        try makeBaseSchemeXML().write(to: schemeURL, atomically: true, encoding: .utf8)

        let installer = BriteLogSchemePreActionInstaller(
            inspector: BriteLogXcodeProjectInspector(),
            backupRootDirectory: backupDirectory,
            isXcodeRunning: { false },
        )
        let initialInspection = try installer.inspect(
            projectURL: projectURL,
            appTarget: resolvedAppTarget,
        )

        let result = try installer.install(
            projectURL: projectURL,
            appTarget: resolvedAppTarget,
            expectedFingerprint: initialInspection.fingerprint,
        )

        let installedXML = try String(contentsOf: result.schemeURL, encoding: .utf8)
        let backupXML = try String(contentsOf: result.backupURL, encoding: .utf8)

        #expect(result.kind == .installed)
        #expect(result.inspection.state == .installed)
        #expect(installedXML.contains("Use BriteLog For Debug Runs"))
        #expect(installedXML.contains("incoming-run-request.env"))
        #expect(installedXML.contains("schemePreAction"))
        #expect(installedXML.contains("com.galewilliams.BriteLog"))
        #expect(backupXML.contains("BuildableProductRunnable"))
    }

    @Test
    func `scheme pre action installer removes only the managed pre action`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectURL = root.appendingPathComponent("ExampleApp.xcodeproj", isDirectory: true)
        let schemeDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
        let schemeURL = schemeDirectory.appendingPathComponent("ExampleApp.xcscheme")
        let backupDirectory = root.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)
        try makeSchemeXMLWithCustomPreAction().write(to: schemeURL, atomically: true, encoding: .utf8)

        let installer = BriteLogSchemePreActionInstaller(
            inspector: BriteLogXcodeProjectInspector(),
            backupRootDirectory: backupDirectory,
            isXcodeRunning: { false },
        )
        let installResult = try installer.install(
            projectURL: projectURL,
            appTarget: resolvedAppTarget,
        )
        let removeResult = try installer.remove(
            projectURL: projectURL,
            appTarget: resolvedAppTarget,
            expectedFingerprint: installResult.inspection.fingerprint,
        )

        let finalXML = try String(contentsOf: schemeURL, encoding: .utf8)

        #expect(removeResult.kind == .removed)
        #expect(removeResult.inspection.state == .notInstalled)
        #expect(finalXML.contains("Keep Existing Action"))
        #expect(finalXML.contains("Use BriteLog For Debug Runs") == false)
    }

    @Test
    func `scheme pre action installer refuses stale writes`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectURL = root.appendingPathComponent("ExampleApp.xcodeproj", isDirectory: true)
        let schemeDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
        let schemeURL = schemeDirectory.appendingPathComponent("ExampleApp.xcscheme")
        let backupDirectory = root.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)
        try makeBaseSchemeXML().write(to: schemeURL, atomically: true, encoding: .utf8)

        let installer = BriteLogSchemePreActionInstaller(
            inspector: BriteLogXcodeProjectInspector(),
            backupRootDirectory: backupDirectory,
            isXcodeRunning: { false },
        )
        let initialInspection = try installer.inspect(
            projectURL: projectURL,
            appTarget: resolvedAppTarget,
        )

        try makeSchemeXMLWithCustomPreAction().write(to: schemeURL, atomically: true, encoding: .utf8)

        #expect(throws: Error.self) {
            try installer.install(
                projectURL: projectURL,
                appTarget: resolvedAppTarget,
                expectedFingerprint: initialInspection.fingerprint,
            )
        }
    }

    @Test
    func `scheme pre action inspection blocks mutation while Xcode is running`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectURL = root.appendingPathComponent("ExampleApp.xcodeproj", isDirectory: true)
        let schemeDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
        let schemeURL = schemeDirectory.appendingPathComponent("ExampleApp.xcscheme")
        try FileManager.default.createDirectory(at: schemeDirectory, withIntermediateDirectories: true)
        try makeBaseSchemeXML().write(to: schemeURL, atomically: true, encoding: .utf8)

        let installer = BriteLogSchemePreActionInstaller(
            inspector: BriteLogXcodeProjectInspector(),
            backupRootDirectory: root.appendingPathComponent("Backups", isDirectory: true),
            isXcodeRunning: { true },
        )

        let inspection = try installer.inspect(
            projectURL: projectURL,
            appTarget: resolvedAppTarget,
        )

        #expect(inspection.canMutate == false)
        #expect(inspection.mutationReadiness == .blockedByRunningXcode)
        #expect(inspection.warnings.isEmpty == false)
    }

    @Test
    func `xcode lifecycle coordinator closes and relaunches xcode`() async throws {
        let xcodeURL = URL(fileURLWithPath: "/Applications/Xcode.app", isDirectory: true)
        let state = TestApplicationState()
        let coordinator = BriteLogXcodeLifecycleCoordinator(
            runningApplications: {
                [
                    .init(
                        bundleIdentifier: BriteLogXcodeLifecycleCoordinator.xcodeBundleIdentifier,
                        bundleURL: xcodeURL,
                        isTerminated: { state.isTerminated },
                        terminate: {
                            state.markTerminated()
                            return true
                        },
                    ),
                ]
            },
            resolveApplicationURL: { _ in xcodeURL },
            launchApplication: { reopenedURL in
                state.recordReopenedURL(reopenedURL)
            },
            sleep: { _ in },
        )

        let relaunchURL = try await coordinator.closeXcodeIfRunning()
        try await coordinator.reopenXcodeIfNeeded(at: relaunchURL)

        #expect(state.didTerminate)
        #expect(relaunchURL == xcodeURL)
        #expect(state.reopenedURL == xcodeURL)
    }

    @Test
    func `xcode lifecycle coordinator times out if xcode does not exit`() async {
        let xcodeURL = URL(fileURLWithPath: "/Applications/Xcode.app", isDirectory: true)
        let state = TestApplicationState()
        let coordinator = BriteLogXcodeLifecycleCoordinator(
            runningApplications: {
                [
                    .init(
                        bundleIdentifier: BriteLogXcodeLifecycleCoordinator.xcodeBundleIdentifier,
                        bundleURL: xcodeURL,
                        isTerminated: { state.isTerminated },
                        terminate: {
                            state.recordTerminateRequest()
                            return true
                        },
                    ),
                ]
            },
            resolveApplicationURL: { _ in xcodeURL },
            launchApplication: { _ in },
            sleep: { _ in },
            terminationTimeout: .zero,
            pollInterval: .zero,
        )

        await #expect(throws: Error.self) {
            try await coordinator.closeXcodeIfRunning()
        }
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }
}

private final class TestApplicationState: @unchecked Sendable {
    private let lock = NSLock()
    private var _isTerminated = false
    private var _didTerminate = false
    private var _reopenedURL: URL?

    var isTerminated: Bool {
        lock.withLock { _isTerminated }
    }

    var didTerminate: Bool {
        lock.withLock { _didTerminate }
    }

    var reopenedURL: URL? {
        lock.withLock { _reopenedURL }
    }

    func markTerminated() {
        lock.withLock {
            _isTerminated = true
            _didTerminate = true
        }
    }

    func recordTerminateRequest() {
        lock.withLock {
            _didTerminate = true
        }
    }

    func recordReopenedURL(_ url: URL) {
        lock.withLock {
            _reopenedURL = url
        }
    }
}

private func makeBaseSchemeXML() -> String {
    """
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
}

private func makeSchemeXMLWithCustomPreAction() -> String {
    """
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
        <PreActions>
          <ExecutionAction ActionType="Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent title="Keep Existing Action" scriptText="echo keep" shellToInvoke="/bin/sh">
              <EnvironmentBuildable>
                <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="ABC123" BuildableName="ExampleApp.app" BlueprintName="ExampleApp" ReferencedContainer="container:ExampleApp.xcodeproj">
                </BuildableReference>
              </EnvironmentBuildable>
            </ActionContent>
          </ExecutionAction>
        </PreActions>
        <BuildableProductRunnable runnableDebuggingMode="0">
          <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="ABC123" BuildableName="ExampleApp.app" BlueprintName="ExampleApp" ReferencedContainer="container:ExampleApp.xcodeproj">
          </BuildableReference>
        </BuildableProductRunnable>
      </LaunchAction>
    </Scheme>
    """
}
