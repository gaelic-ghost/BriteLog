import Foundation

struct BriteLogSchemePreActionInstaller {
    nonisolated static let actionTitle = "Use BriteLog For Debug Runs"
    nonisolated static let actionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction"
    nonisolated static let appBundleIdentifier = "com.galewilliams.BriteLog"

    var inspector: BriteLogXcodeProjectInspector

    nonisolated init(inspector: BriteLogXcodeProjectInspector = .init()) {
        self.inspector = inspector
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

    private nonisolated static func shellQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        return "\"\(escaped)\""
    }

    nonisolated func install(
        projectURL: URL,
        appTarget: BriteLogXcodeResolvedAppTarget,
    ) throws -> URL {
        let schemeURL = inspector.sharedSchemeURL(
            projectURL: projectURL,
            schemeName: appTarget.schemeName,
        )

        guard FileManager.default.fileExists(atPath: schemeURL.path) else {
            throw BriteLogSchemePreActionInstallerError(
                """
                BriteLog can only install into shared schemes right now, and the selected scheme file does not exist on disk.
                Expected shared scheme:
                \(schemeURL.path)

                Share the scheme in Xcode first, then try again.
                """,
            )
        }

        let document = try XMLDocument(contentsOf: schemeURL, options: .nodePreserveAll)
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

        document.characterEncoding = "UTF-8"
        document.version = "1.0"
        let data = document.xmlData(options: [.nodePrettyPrint])
        try data.write(to: schemeURL, options: [.atomic])
        return schemeURL
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
        let children = preActions.elements(forName: "ExecutionAction")
        for action in children {
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

private struct BriteLogSchemePreActionInstallerError: LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
