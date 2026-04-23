import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProjectIntegrationInstallerSection: View {
    private enum PendingSchemeAction {
        case installOrUpdate
        case remove

        var confirmationTitle: String {
            switch self {
                case .installOrUpdate:
                    "Close Xcode, Apply, And Reopen"
                case .remove:
                    "Close Xcode, Remove, And Reopen"
            }
        }

        var progressMessage: String {
            switch self {
                case .installOrUpdate:
                    "Closing Xcode, updating the shared scheme safely, and reopening Xcode..."
                case .remove:
                    "Closing Xcode, removing the shared scheme pre-action safely, and reopening Xcode..."
            }
        }
    }

    @Environment(BriteLogAppModel.self) private var model

    @State private var projectPath = ""
    @State private var inspection: BriteLogXcodeProjectInspection?
    @State private var selectedSchemeName = ""
    @State private var resolvedAppTarget: BriteLogXcodeResolvedAppTarget?
    @State private var schemeInspection: BriteLogSchemePreActionInspection?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var pendingSchemeAction: PendingSchemeAction?
    @State private var isWorking = false

    private let projectInspector = BriteLogXcodeProjectInspector()
    private let schemeInstaller = BriteLogSchemePreActionInstaller()
    private let xcodeLifecycleCoordinator = BriteLogXcodeLifecycleCoordinator()

    private var canInstallOrUpdate: Bool {
        resolvedAppTarget != nil && schemeInspection != nil
    }

    private var canRemove: Bool {
        guard let schemeInspection else {
            return false
        }

        return resolvedAppTarget != nil && schemeInspection.state != .notInstalled
    }

    private var installButtonTitle: String {
        switch schemeInspection?.state {
            case .installed:
                "Reinstall BriteLog Pre-Action"
            case .drifted:
                "Repair BriteLog Pre-Action"
            default:
                "Install BriteLog Pre-Action"
        }
    }

    var body: some View {
        GroupBox("Project Integration") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Install the first BriteLog Xcode integration as a shared scheme pre-action. This gives the app a real \"a debug run is starting now\" signal without turning a build-time plugin into the live watcher.")
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 8) {
                    TextField("Path to a shared-scheme .xcodeproj", text: $projectPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isWorking)

                    Button("Choose Project…") {
                        chooseProject()
                    }
                    .disabled(isWorking)

                    Button("Inspect") {
                        inspectProject()
                    }
                    .disabled(isWorking || projectPath.isEmpty)
                }

                if let inspection {
                    Picker("Scheme", selection: $selectedSchemeName) {
                        ForEach(inspection.schemes, id: \.self) { schemeName in
                            Text(schemeName)
                                .tag(schemeName)
                        }
                    }
                    .onChange(of: selectedSchemeName) { _, _ in
                        resolveSelectedScheme()
                    }
                    .disabled(isWorking)

                    if let resolvedAppTarget {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bundle Identifier")
                                .font(.subheadline.weight(.semibold))
                            Text(resolvedAppTarget.bundleIdentifier)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)

                            if let targetName = resolvedAppTarget.targetName, !targetName.isEmpty {
                                Text("Target: \(targetName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let schemeInspection {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Integration Status")
                                .font(.subheadline.weight(.semibold))
                            Text(schemeInspection.state.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(schemeInspection.state == .installed ? .green : .secondary)
                            Text(schemeInspection.schemeURL.path)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)

                            if let lastModifiedAt = schemeInspection.lastModifiedAt {
                                Text("Scheme last modified: \(lastModifiedAt.formatted(date: .abbreviated, time: .standard))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(schemeInspection.warnings, id: \.self) { warning in
                                Text(warning)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button(installButtonTitle) {
                            installOrUpdateSelectedScheme()
                        }
                        .disabled(isWorking || resolvedAppTarget == nil || !canInstallOrUpdate)

                        Button("Remove BriteLog Pre-Action") {
                            removeSelectedScheme()
                        }
                        .disabled(isWorking || resolvedAppTarget == nil || !canRemove)
                    }
                }

                if isWorking {
                    ProgressView()
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert(
            pendingSchemeAction?.confirmationTitle ?? "",
            isPresented: Binding(
                get: { pendingSchemeAction != nil },
                set: { if !$0 { pendingSchemeAction = nil } },
            ),
            presenting: pendingSchemeAction,
        ) { action in
            Button(action.confirmationTitle) {
                performPendingSchemeAction(action)
            }
            Button("Cancel", role: .cancel) {
                pendingSchemeAction = nil
            }
        } message: { action in
            Text("""
            Xcode is open right now.

            BriteLog can safely handle this for you by:
            1. asking Xcode to quit
            2. waiting for Xcode to fully terminate
            3. updating only the shared `.xcscheme`
            4. reopening Xcode afterward
            """)
        }
    }

    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let xcodeProjectType = UTType(filenameExtension: "xcodeproj") {
            panel.allowedContentTypes = [xcodeProjectType]
        }

        if panel.runModal() == .OK, let url = panel.url {
            projectPath = url.path
            inspection = nil
            selectedSchemeName = ""
            resolvedAppTarget = nil
            schemeInspection = nil
            statusMessage = nil
            errorMessage = nil
        }
    }

    private func inspectProject() {
        guard !projectPath.isEmpty else {
            return
        }

        isWorking = true
        statusMessage = nil
        errorMessage = nil

        let projectURL = URL(fileURLWithPath: projectPath)

        Task {
            do {
                let inspection = try await Task.detached {
                    try projectInspector.inspectProject(at: projectURL)
                }
                .value

                self.inspection = inspection
                selectedSchemeName = inspection.preferredScheme
                statusMessage = "Loaded \(inspection.schemes.count) shared scheme(s) from \(inspection.projectName)."
                errorMessage = nil
                isWorking = false
                resolveSelectedScheme()
            } catch {
                inspection = nil
                selectedSchemeName = ""
                resolvedAppTarget = nil
                schemeInspection = nil
                statusMessage = nil
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }

    private func resolveSelectedScheme() {
        guard let inspection, !selectedSchemeName.isEmpty else {
            resolvedAppTarget = nil
            schemeInspection = nil
            return
        }

        let schemeName = selectedSchemeName
        isWorking = true
        errorMessage = nil

        Task {
            do {
                let resolvedTarget = try await Task.detached {
                    try projectInspector.resolveAppTarget(
                        projectURL: inspection.projectURL,
                        schemeName: schemeName,
                    )
                }
                .value

                resolvedAppTarget = resolvedTarget
                let schemeInspection = try await Task.detached {
                    try schemeInstaller.inspect(
                        projectURL: inspection.projectURL,
                        appTarget: resolvedTarget,
                    )
                }
                .value

                self.schemeInspection = schemeInspection
                isWorking = false
            } catch {
                resolvedAppTarget = nil
                schemeInspection = nil
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }

    private func installOrUpdateSelectedScheme() {
        guard let schemeInspection else {
            return
        }

        if schemeInspection.mutationReadiness == .blockedByRunningXcode {
            pendingSchemeAction = .installOrUpdate
            return
        }

        performInstallOrUpdate(reopenXcodeAfterward: false)
    }

    private func removeSelectedScheme() {
        guard let schemeInspection else {
            return
        }

        if schemeInspection.mutationReadiness == .blockedByRunningXcode {
            pendingSchemeAction = .remove
            return
        }

        performRemove(reopenXcodeAfterward: false)
    }

    private func performPendingSchemeAction(_ action: PendingSchemeAction) {
        pendingSchemeAction = nil

        switch action {
            case .installOrUpdate:
                performInstallOrUpdate(reopenXcodeAfterward: true)
            case .remove:
                performRemove(reopenXcodeAfterward: true)
        }
    }

    private func performInstallOrUpdate(reopenXcodeAfterward: Bool) {
        guard let inspection, let resolvedAppTarget, let schemeInspection else {
            return
        }

        isWorking = true
        statusMessage = reopenXcodeAfterward ? PendingSchemeAction.installOrUpdate.progressMessage : nil
        errorMessage = nil

        Task {
            do {
                let xcodeURL: URL? = if reopenXcodeAfterward {
                    try await xcodeLifecycleCoordinator.closeXcodeIfRunning()
                } else {
                    nil
                }

                let result: BriteLogSchemePreActionMutationResult
                do {
                    result = try await Task.detached {
                        try schemeInstaller.install(
                            projectURL: inspection.projectURL,
                            appTarget: resolvedAppTarget,
                            expectedFingerprint: schemeInspection.fingerprint,
                        )
                    }
                    .value
                } catch {
                    if reopenXcodeAfterward {
                        try? await xcodeLifecycleCoordinator.reopenXcodeIfNeeded(at: xcodeURL)
                    }
                    throw error
                }

                if reopenXcodeAfterward {
                    try await xcodeLifecycleCoordinator.reopenXcodeIfNeeded(at: xcodeURL)
                }

                model.addProjectInstall(
                    displayName: resolvedAppTarget.targetName ?? inspection.projectName,
                    projectPath: inspection.projectURL.path,
                    schemeName: resolvedAppTarget.schemeName,
                    bundleIdentifier: resolvedAppTarget.bundleIdentifier,
                    schemePath: result.schemeURL.path,
                    schemeFingerprint: result.inspection.fingerprint,
                    backupPath: result.backupURL.path,
                    integrationKind: .schemePreAction,
                    notes: "Shared scheme pre-action installed safely with a backup at \(result.backupURL.path).",
                )

                self.schemeInspection = result.inspection
                statusMessage = """
                Installed the BriteLog scheme pre-action into:
                \(result.schemeURL.path)

                Backup copy:
                \(result.backupURL.path)

                \(reopenXcodeAfterward ? "Xcode was reopened after the scheme update." : "")
                """
                errorMessage = nil
                isWorking = false
            } catch {
                statusMessage = nil
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }

    private func performRemove(reopenXcodeAfterward: Bool) {
        guard let inspection, let resolvedAppTarget, let schemeInspection else {
            return
        }

        isWorking = true
        statusMessage = reopenXcodeAfterward ? PendingSchemeAction.remove.progressMessage : nil
        errorMessage = nil

        Task {
            do {
                let xcodeURL: URL? = if reopenXcodeAfterward {
                    try await xcodeLifecycleCoordinator.closeXcodeIfRunning()
                } else {
                    nil
                }

                let result: BriteLogSchemePreActionMutationResult
                do {
                    result = try await Task.detached {
                        try schemeInstaller.remove(
                            projectURL: inspection.projectURL,
                            appTarget: resolvedAppTarget,
                            expectedFingerprint: schemeInspection.fingerprint,
                        )
                    }
                    .value
                } catch {
                    if reopenXcodeAfterward {
                        try? await xcodeLifecycleCoordinator.reopenXcodeIfNeeded(at: xcodeURL)
                    }
                    throw error
                }

                if reopenXcodeAfterward {
                    try await xcodeLifecycleCoordinator.reopenXcodeIfNeeded(at: xcodeURL)
                }

                model.removeProjectInstall(
                    projectPath: inspection.projectURL.path,
                    schemeName: resolvedAppTarget.schemeName,
                    integrationKind: .schemePreAction,
                )

                self.schemeInspection = result.inspection
                statusMessage = """
                Removed the BriteLog scheme pre-action from:
                \(result.schemeURL.path)

                Backup copy:
                \(result.backupURL.path)

                \(reopenXcodeAfterward ? "Xcode was reopened after the scheme update." : "")
                """
                errorMessage = nil
                isWorking = false
            } catch {
                statusMessage = nil
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }
}
