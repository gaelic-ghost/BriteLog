import AppKit
import CryptoKit
import Foundation

struct BriteLogSchemePreActionInspection: Equatable {
    enum State: String, Equatable {
        case notInstalled
        case installed
        case drifted

        var displayName: String {
            switch self {
                case .notInstalled:
                    "Not Installed"
                case .installed:
                    "Installed"
                case .drifted:
                    "Needs Repair"
            }
        }
    }

    enum MutationReadiness: Equatable {
        case ready
        case blockedByRunningXcode

        var canMutate: Bool {
            self == .ready
        }
    }

    var schemeURL: URL
    var fingerprint: String
    var state: State
    var mutationReadiness: MutationReadiness
    var warnings: [String]
    var lastModifiedAt: Date?

    var canMutate: Bool {
        mutationReadiness.canMutate
    }
}

struct BriteLogSchemePreActionMutationResult: Equatable {
    enum Kind: Equatable {
        case installed
        case removed
    }

    var kind: Kind
    var schemeURL: URL
    var backupURL: URL
    var inspection: BriteLogSchemePreActionInspection
}

struct BriteLogSchemePreActionInstaller {
    nonisolated static let actionTitle = "Use BriteLog For Debug Runs"
    nonisolated static let actionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction"
    nonisolated static let appBundleIdentifier = "com.galewilliams.BriteLog"
    nonisolated static let xcodeBundleIdentifier = "com.apple.dt.Xcode"

    nonisolated let inspector: BriteLogXcodeProjectInspector
    nonisolated let backupRootDirectory: URL
    nonisolated let isXcodeRunning: @Sendable () -> Bool

    nonisolated init(
        inspector: BriteLogXcodeProjectInspector = .init(),
        fileManager: FileManager = .default,
        backupRootDirectory: URL? = nil,
        isXcodeRunning: @escaping @Sendable () -> Bool = Self.defaultXcodeRunningCheck,
    ) {
        self.inspector = inspector
        self.backupRootDirectory = backupRootDirectory
            ?? BriteLogAppStorage.defaultApplicationSupportDirectory(
                fileManager: fileManager,
                applicationIdentifier: BriteLogAppStorage.defaultApplicationIdentifier,
            )
            .appendingPathComponent("integration-backups", isDirectory: true)
        self.isXcodeRunning = isXcodeRunning
    }

    nonisolated static func makeScriptText(
        projectPath: String,
        schemeName: String,
        defaultTargetName: String?,
        defaultBundleIdentifier: String,
    ) -> String {
        let escapedProjectPath = shellQuoted(projectPath)
        let escapedSchemeName = shellQuoted(schemeName)
        let escapedTargetName = shellQuoted(defaultTargetName ?? "")
        let escapedBundleIdentifier = shellQuoted(defaultBundleIdentifier)
        let escapedSupportDirectory = shellQuoted(
            "~/Library/Application Support/\(BriteLogAppStorage.defaultApplicationIdentifier)",
        )
        let escapedAppBundleIdentifier = shellQuoted(appBundleIdentifier)

        return [
            "set -eu",
            "",
            "BRITELOG_SUPPORT_DIR=$(/usr/bin/eval /bin/echo \(escapedSupportDirectory))",
            "BRITELOG_REQUEST_PATH=\"$BRITELOG_SUPPORT_DIR/incoming-run-request.env\"",
            "",
            "britelog_encode() {",
            "  /usr/bin/printf '%s' \"$1\" | /usr/bin/base64 | /usr/bin/tr -d '\\n'",
            "}",
            "",
            "REQUEST_ID=$(/usr/bin/uuidgen)",
            "SUBMITTED_AT=$(/bin/date -u +\"%Y-%m-%dT%H:%M:%SZ\")",
            "PROJECT_PATH_VALUE=\"${PROJECT_FILE_PATH:-\(escapedProjectPath)}\"",
            "TARGET_NAME_VALUE=\"${TARGET_NAME:-\(escapedTargetName)}\"",
            "BUNDLE_IDENTIFIER_VALUE=\"${PRODUCT_BUNDLE_IDENTIFIER:-\(escapedBundleIdentifier)}\"",
            "BUILD_CONFIGURATION_VALUE=\"${CONFIGURATION:-Debug}\"",
            "BUILT_PRODUCT_PATH_VALUE=\"\"",
            "",
            "if [ -n \"${TARGET_BUILD_DIR:-}\" ] && [ -n \"${FULL_PRODUCT_NAME:-}\" ]; then",
            "  BUILT_PRODUCT_PATH_VALUE=\"${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}\"",
            "fi",
            "",
            "/bin/mkdir -p \"$BRITELOG_SUPPORT_DIR\"",
            "",
            "cat > \"$BRITELOG_REQUEST_PATH\" <<EOF",
            "requestID=$REQUEST_ID",
            "submittedAt=$SUBMITTED_AT",
            "source=schemePreAction",
            "projectPath_b64=$(britelog_encode \"$PROJECT_PATH_VALUE\")",
            "schemeName_b64=$(britelog_encode \(escapedSchemeName))",
            "targetName_b64=$(britelog_encode \"$TARGET_NAME_VALUE\")",
            "bundleIdentifier_b64=$(britelog_encode \"$BUNDLE_IDENTIFIER_VALUE\")",
            "buildConfiguration_b64=$(britelog_encode \"$BUILD_CONFIGURATION_VALUE\")",
            "builtProductPath_b64=$(britelog_encode \"$BUILT_PRODUCT_PATH_VALUE\")",
            "EOF",
            "",
            "/usr/bin/open -b \(escapedAppBundleIdentifier) >/dev/null 2>&1 || true",
        ].joined(separator: "\n")
    }

    nonisolated static func defaultXcodeRunningCheck() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: xcodeBundleIdentifier).isEmpty
    }

    private nonisolated static func shellQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        return "\"\(escaped)\""
    }

    nonisolated func inspect(
        projectURL: URL,
        appTarget: BriteLogXcodeResolvedAppTarget,
    ) throws -> BriteLogSchemePreActionInspection {
        let schemeURL = inspector.sharedSchemeURL(
            projectURL: projectURL,
            schemeName: appTarget.schemeName,
        )
        let schemeData = try loadSchemeData(schemeURL: schemeURL)
        let document = try XMLDocument(data: schemeData, options: .nodePreserveAll)
        guard let scheme = document.rootElement() else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog could not parse the selected `.xcscheme` file because it does not contain a root `Scheme` element.
                Scheme file:
                \(schemeURL.path)
                """,
            )
        }

        let managedActions = findManagedBriteLogActions(in: scheme)
        let state: BriteLogSchemePreActionInspection.State = switch managedActions.count {
            case 0:
                .notInstalled
            case 1 where managedActions[0].looksHealthy:
                .installed
            default:
                .drifted
        }

        return BriteLogSchemePreActionInspection(
            schemeURL: schemeURL,
            fingerprint: fingerprint(for: schemeData),
            state: state,
            mutationReadiness: isXcodeRunning() ? .blockedByRunningXcode : .ready,
            warnings: mutationWarnings(schemeURL: schemeURL),
            lastModifiedAt: lastModifiedDate(for: schemeURL),
        )
    }

    nonisolated func install(
        projectURL: URL,
        appTarget: BriteLogXcodeResolvedAppTarget,
        expectedFingerprint: String? = nil,
    ) throws -> BriteLogSchemePreActionMutationResult {
        let schemeURL = inspector.sharedSchemeURL(
            projectURL: projectURL,
            schemeName: appTarget.schemeName,
        )
        let document = try prepareMutableSchemeDocument(
            projectURL: projectURL,
            schemeURL: schemeURL,
            expectedFingerprint: expectedFingerprint,
            operationDescription: "install or update the BriteLog scheme pre-action",
        )

        guard let scheme = document.rootElement() else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog could not parse the selected `.xcscheme` file because it does not contain a root `Scheme` element.
                Scheme file:
                \(schemeURL.path)
                """,
            )
        }
        guard let launchAction = scheme.elements(forName: "LaunchAction").first else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog could not find a `LaunchAction` in the selected scheme.
                Scheme file:
                \(schemeURL.path)
                """,
            )
        }

        let buildableReference = try resolveEnvironmentBuildableReference(
            scheme: scheme,
            launchAction: launchAction,
            schemeURL: schemeURL,
        )

        let preActions = ensureChild(named: "PreActions", under: launchAction)
        removeExistingBriteLogActions(from: preActions)
        preActions.addChild(
            makeExecutionAction(
                buildableReference: buildableReference,
                scriptText: Self.makeScriptText(
                    projectPath: projectURL.path,
                    schemeName: appTarget.schemeName,
                    defaultTargetName: appTarget.targetName,
                    defaultBundleIdentifier: appTarget.bundleIdentifier,
                ),
            ),
        )

        let backupURL = try writeUpdatedScheme(
            document: document,
            schemeURL: schemeURL,
            projectURL: projectURL,
            schemeName: appTarget.schemeName,
        )
        let inspection = try inspect(projectURL: projectURL, appTarget: appTarget)
        guard inspection.state == .installed else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog wrote the updated scheme file, but the follow-up inspection did not find a healthy installed pre-action state.
                Scheme file:
                \(schemeURL.path)
                """,
            )
        }

        return BriteLogSchemePreActionMutationResult(
            kind: .installed,
            schemeURL: schemeURL,
            backupURL: backupURL,
            inspection: inspection,
        )
    }

    nonisolated func remove(
        projectURL: URL,
        appTarget: BriteLogXcodeResolvedAppTarget,
        expectedFingerprint: String? = nil,
    ) throws -> BriteLogSchemePreActionMutationResult {
        let schemeURL = inspector.sharedSchemeURL(
            projectURL: projectURL,
            schemeName: appTarget.schemeName,
        )
        let document = try prepareMutableSchemeDocument(
            projectURL: projectURL,
            schemeURL: schemeURL,
            expectedFingerprint: expectedFingerprint,
            operationDescription: "remove the BriteLog scheme pre-action",
        )

        guard let scheme = document.rootElement() else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog could not parse the selected `.xcscheme` file because it does not contain a root `Scheme` element.
                Scheme file:
                \(schemeURL.path)
                """,
            )
        }
        guard let launchAction = scheme.elements(forName: "LaunchAction").first else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog could not find a `LaunchAction` in the selected scheme.
                Scheme file:
                \(schemeURL.path)
                """,
            )
        }

        if let preActions = launchAction.elements(forName: "PreActions").first {
            removeExistingBriteLogActions(from: preActions)
        }

        let backupURL = try writeUpdatedScheme(
            document: document,
            schemeURL: schemeURL,
            projectURL: projectURL,
            schemeName: appTarget.schemeName,
        )
        let inspection = try inspect(projectURL: projectURL, appTarget: appTarget)
        guard inspection.state == .notInstalled else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog wrote the updated scheme file, but the follow-up inspection still found a managed pre-action.
                Scheme file:
                \(schemeURL.path)
                """,
            )
        }

        return BriteLogSchemePreActionMutationResult(
            kind: .removed,
            schemeURL: schemeURL,
            backupURL: backupURL,
            inspection: inspection,
        )
    }

    private nonisolated func loadSchemeData(schemeURL: URL) throws -> Data {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: schemeURL.path) else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog can only install into shared schemes right now, and the selected scheme file does not exist on disk.
                Expected shared scheme:
                \(schemeURL.path)

                Share the scheme in Xcode first, then try again.
                """,
            )
        }

        return try Data(contentsOf: schemeURL)
    }

    private nonisolated func prepareMutableSchemeDocument(
        projectURL: URL,
        schemeURL: URL,
        expectedFingerprint: String?,
        operationDescription: String,
    ) throws -> XMLDocument {
        if isXcodeRunning() {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog will not \(operationDescription) while Xcode is open.

                Close Xcode first so BriteLog is not racing the IDE over the same shared scheme file:
                \(schemeURL.path)

                BriteLog intentionally only edits the shared `.xcscheme` file and never mutates the project’s `.pbxproj`.
                """,
            )
        }

        let schemeData = try loadSchemeData(schemeURL: schemeURL)
        let currentFingerprint = fingerprint(for: schemeData)
        if let expectedFingerprint, expectedFingerprint != currentFingerprint {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog refused to write the shared scheme because it changed after the last inspection.

                Project:
                \(projectURL.path)

                Scheme file:
                \(schemeURL.path)

                Re-inspect the project so BriteLog can review the latest scheme contents before it tries again.
                """,
            )
        }

        return try XMLDocument(data: schemeData, options: .nodePreserveAll)
    }

    private nonisolated func mutationWarnings(schemeURL: URL) -> [String] {
        guard isXcodeRunning() else {
            return []
        }

        return [
            """
            Xcode is running right now, so BriteLog will stay in inspect-only mode for this scheme.
            Close Xcode before you install, update, or remove the shared scheme pre-action:
            \(schemeURL.path)
            """,
        ]
    }

    private nonisolated func writeUpdatedScheme(
        document: XMLDocument,
        schemeURL: URL,
        projectURL: URL,
        schemeName: String,
    ) throws -> URL {
        let fileManager = FileManager.default
        let schemeDirectoryURL = schemeURL.deletingLastPathComponent()
        let tempURL = schemeDirectoryURL.appendingPathComponent(
            ".\(schemeURL.lastPathComponent).britelog-\(UUID().uuidString).tmp",
        )
        let backupURL = try makeBackupURL(projectURL: projectURL, schemeName: schemeName)

        document.characterEncoding = "UTF-8"
        document.version = "1.0"

        try ensureBackupDirectoryExists()
        try fileManager.copyItem(at: schemeURL, to: backupURL)

        let data = document.xmlData(options: [.nodePrettyPrint])
        do {
            try data.write(to: tempURL, options: [.atomic])
            _ = try fileManager.replaceItemAt(
                schemeURL,
                withItemAt: tempURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly],
            )
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog could not safely replace the shared scheme file.
                Scheme file:
                \(schemeURL.path)

                A backup copy of the previous scheme was saved at:
                \(backupURL.path)

                Underlying error:
                \(error.localizedDescription)
                """,
            )
        }

        return backupURL
    }

    private nonisolated func makeBackupURL(
        projectURL: URL,
        schemeName: String,
    ) throws -> URL {
        let fileManager = FileManager.default
        let projectDirectory = backupRootDirectory.appendingPathComponent(
            sanitizedPathComponent(projectURL.deletingPathExtension().lastPathComponent),
            isDirectory: true,
        )
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "\(sanitizedPathComponent(schemeName))-\(timestamp)-\(UUID().uuidString).xcscheme"
        return projectDirectory.appendingPathComponent(fileName)
    }

    private nonisolated func ensureBackupDirectoryExists() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: backupRootDirectory, withIntermediateDirectories: true)
    }

    private nonisolated func sanitizedPathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let sanitized = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(sanitized)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "scheme" : result
    }

    private nonisolated func fingerprint(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated func lastModifiedDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    private nonisolated func findManagedBriteLogActions(in scheme: XMLElement) -> [ManagedAction] {
        guard let launchAction = scheme.elements(forName: "LaunchAction").first else {
            return []
        }
        guard let preActions = launchAction.elements(forName: "PreActions").first else {
            return []
        }

        return preActions
            .elements(forName: "ExecutionAction")
            .compactMap { action in
                guard let actionContent = action.elements(forName: "ActionContent").first else {
                    return nil
                }
                guard actionContent.attribute(forName: "title")?.stringValue == Self.actionTitle else {
                    return nil
                }

                return ManagedAction(
                    scriptText: actionContent.attribute(forName: "scriptText")?.stringValue ?? "",
                )
            }
    }

    private nonisolated func resolveEnvironmentBuildableReference(
        scheme: XMLElement,
        launchAction: XMLElement,
        schemeURL: URL,
    ) throws -> XMLElement {
        if let buildableReference = launchAction
            .elements(forName: "BuildableProductRunnable")
            .first?
            .elements(forName: "BuildableReference")
            .first {
            return buildableReference.copy() as! XMLElement
        }

        if let buildableReference = launchAction
            .elements(forName: "MacroExpansion")
            .first?
            .elements(forName: "BuildableReference")
            .first {
            return buildableReference.copy() as! XMLElement
        }

        if let buildableReference = scheme
            .elements(forName: "BuildAction")
            .first?
            .elements(forName: "BuildActionEntries")
            .first?
            .elements(forName: "BuildActionEntry")
            .first?
            .elements(forName: "BuildableReference")
            .first {
            return buildableReference.copy() as! XMLElement
        }

        throw BriteLogSchemePreActionInstallerError(
            """
            BriteLog could not find a buildable reference to attach to the scheme pre-action.
            Scheme file:
            \(schemeURL.path)
            """,
        )
    }

    private nonisolated func ensureChild(
        named name: String,
        under element: XMLElement,
    ) -> XMLElement {
        if let existing = element.elements(forName: name).first {
            return existing
        }

        let child = XMLElement(name: name)
        element.addChild(child)
        return child
    }

    private nonisolated func removeExistingBriteLogActions(from preActions: XMLElement) {
        for action in preActions.elements(forName: "ExecutionAction").reversed() {
            guard let actionContent = action.elements(forName: "ActionContent").first else {
                continue
            }

            if actionContent.attribute(forName: "title")?.stringValue == Self.actionTitle {
                preActions.removeChild(at: action.index)
            }
        }
    }

    private nonisolated func makeExecutionAction(
        buildableReference: XMLElement,
        scriptText: String,
    ) -> XMLElement {
        let action = XMLElement(name: "ExecutionAction")
        action.addAttribute(XMLNode.attribute(withName: "ActionType", stringValue: Self.actionType) as! XMLNode)

        let actionContent = XMLElement(name: "ActionContent")
        actionContent.addAttribute(XMLNode.attribute(withName: "title", stringValue: Self.actionTitle) as! XMLNode)
        actionContent.addAttribute(XMLNode.attribute(withName: "scriptText", stringValue: scriptText) as! XMLNode)
        actionContent.addAttribute(XMLNode.attribute(withName: "shellToInvoke", stringValue: "/bin/sh") as! XMLNode)

        let environmentBuildable = XMLElement(name: "EnvironmentBuildable")
        environmentBuildable.addChild(buildableReference)
        actionContent.addChild(environmentBuildable)
        action.addChild(actionContent)
        return action
    }
}

private struct ManagedAction: Equatable {
    var scriptText: String

    nonisolated var looksHealthy: Bool {
        scriptText.contains("incoming-run-request.env")
            && scriptText.contains("source=schemePreAction")
            && scriptText.contains(BriteLogSchemePreActionInstaller.appBundleIdentifier)
    }
}

private struct BriteLogSchemePreActionInstallerError: LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
