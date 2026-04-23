import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProjectIntegrationInstallerSection: View {
    @Environment(BriteLogAppModel.self) private var model

    @State private var projectPath = ""
    @State private var inspection: BriteLogXcodeProjectInspection?
    @State private var selectedSchemeName = ""
    @State private var resolvedAppTarget: BriteLogXcodeResolvedAppTarget?
    @State private var schemeInspection: BriteLogSchemePreActionInspection?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isWorking = false

    private let projectInspector = BriteLogXcodeProjectInspector()
    private let schemeInstaller = BriteLogSchemePreActionInstaller()

    private var canInstallOrUpdate: Bool {
        guard let schemeInspection else {
            return false
        }

        return schemeInspection.canMutate
    }

    private var canRemove: Bool {
        guard let schemeInspection else {
            return false
        }

        return schemeInspection.canMutate && schemeInspection.state != .notInstalled
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
        guard let inspection, let resolvedAppTarget, let schemeInspection else {
            return
        }

        isWorking = true
        statusMessage = nil
        errorMessage = nil

        Task {
            do {
                let result = try await Task.detached {
                    try schemeInstaller.install(
                        projectURL: inspection.projectURL,
                        appTarget: resolvedAppTarget,
                        expectedFingerprint: schemeInspection.fingerprint,
                    )
                }
                .value

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

    private func removeSelectedScheme() {
        guard let inspection, let resolvedAppTarget, let schemeInspection else {
            return
        }

        isWorking = true
        statusMessage = nil
        errorMessage = nil

        Task {
            do {
                let result = try await Task.detached {
                    try schemeInstaller.remove(
                        projectURL: inspection.projectURL,
                        appTarget: resolvedAppTarget,
                        expectedFingerprint: schemeInspection.fingerprint,
                    )
                }
                .value

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
