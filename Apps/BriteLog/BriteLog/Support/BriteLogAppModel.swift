import AppKit
import BriteLogCore
import Foundation
import Observation

@MainActor
@Observable
final class BriteLogAppModel {
    let storage: BriteLogAppStorage

    var configuration: BriteLogAppConfiguration
    var projectInstalls: [BriteLogProjectInstall]
    var currentRunRequest: BriteLogRunRequest?
    var observedApplication: BriteLogObservedApplication?
    var lastErrorDescription: String?

    private var runRequestPollingTask: Task<Void, Never>?
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

    var applicationSupportPath: String {
        storage.applicationSupportDirectory.path
    }

    init(storage: BriteLogAppStorage = .init()) {
        self.storage = storage
        configuration = .default
        projectInstalls = []
        currentRunRequest = nil
        observedApplication = nil
        lastErrorDescription = nil
        reloadFromDisk()
        configureWorkspaceNotifications()
        startRunRequestPolling()
    }

    func reloadFromDisk() {
        do {
            configuration = try storage.loadConfiguration()
            projectInstalls = try storage.loadProjectInstalls()
            currentRunRequest = try storage.loadCurrentRunRequest()
            refreshObservedApplicationFromWorkspace()
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    func setSelectedTheme(_ theme: BriteLogTheme) {
        configuration.selectedTheme = theme
        persistConfiguration()
    }

    func setShowViewerOnLaunch(_ value: Bool) {
        configuration.showViewerOnLaunch = value
        persistConfiguration()
    }

    func addProjectInstall(
        displayName: String,
        projectPath: String,
        schemeName: String? = nil,
        bundleIdentifier: String? = nil,
        schemePath: String? = nil,
        schemeFingerprint: String? = nil,
        backupPath: String? = nil,
        integrationKind: BriteLogProjectInstall.IntegrationKind,
        notes: String? = nil,
    ) {
        let now = Date()

        if let existingIndex = projectInstalls.firstIndex(where: {
            $0.projectPath == projectPath && $0.schemeName == schemeName && $0.integrationKind == integrationKind
        }) {
            projectInstalls[existingIndex].displayName = displayName
            projectInstalls[existingIndex].bundleIdentifier = bundleIdentifier
            projectInstalls[existingIndex].schemePath = schemePath
            projectInstalls[existingIndex].schemeFingerprint = schemeFingerprint
            projectInstalls[existingIndex].backupPath = backupPath
            projectInstalls[existingIndex].notes = notes
            projectInstalls[existingIndex].updatedAt = now
        } else {
            projectInstalls.append(
                BriteLogProjectInstall(
                    displayName: displayName,
                    projectPath: projectPath,
                    schemeName: schemeName,
                    bundleIdentifier: bundleIdentifier,
                    schemePath: schemePath,
                    schemeFingerprint: schemeFingerprint,
                    backupPath: backupPath,
                    integrationKind: integrationKind,
                    notes: notes,
                    createdAt: now,
                    updatedAt: now,
                ),
            )
        }

        persistProjectInstalls()
    }

    func removeProjectInstall(
        projectPath: String,
        schemeName: String? = nil,
        integrationKind: BriteLogProjectInstall.IntegrationKind,
    ) {
        projectInstalls.removeAll {
            $0.projectPath == projectPath && $0.schemeName == schemeName && $0.integrationKind == integrationKind
        }
        persistProjectInstalls()
    }

    func importIncomingRunRequestIfNeeded() {
        do {
            guard let request = try storage.consumeIncomingRunRequest() else {
                return
            }

            currentRunRequest = request
            try storage.saveCurrentRunRequest(request)
            refreshObservedApplicationFromWorkspace()
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    private func persistConfiguration() {
        do {
            try storage.saveConfiguration(configuration)
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    private func persistProjectInstalls() {
        do {
            try storage.saveProjectInstalls(projectInstalls)
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    private func startRunRequestPolling() {
        runRequestPollingTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await MainActor.run {
                    self.importIncomingRunRequestIfNeeded()
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func configureWorkspaceNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        launchObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: NSWorkspace.shared,
            queue: nil,
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            let bundleIdentifier = application.bundleIdentifier
            let localizedName = application.localizedName
            let processIdentifier = application.processIdentifier
            Task { @MainActor in
                self?.handleWorkspaceApplicationEvent(
                    bundleIdentifier: bundleIdentifier,
                    localizedName: localizedName,
                    processIdentifier: processIdentifier,
                    phase: .running,
                )
            }
        }

        terminateObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: NSWorkspace.shared,
            queue: nil,
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            let bundleIdentifier = application.bundleIdentifier
            let localizedName = application.localizedName
            let processIdentifier = application.processIdentifier
            Task { @MainActor in
                self?.handleWorkspaceApplicationEvent(
                    bundleIdentifier: bundleIdentifier,
                    localizedName: localizedName,
                    processIdentifier: processIdentifier,
                    phase: .terminated,
                )
            }
        }
    }

    private func handleWorkspaceApplicationEvent(
        bundleIdentifier: String?,
        localizedName: String?,
        processIdentifier: pid_t,
        phase: BriteLogObservedApplication.Phase,
    ) {
        guard let currentRunRequest else {
            return
        }
        guard let bundleIdentifier else {
            return
        }
        guard bundleIdentifier == currentRunRequest.bundleIdentifier else {
            return
        }

        observedApplication = BriteLogObservedApplication(
            bundleIdentifier: currentRunRequest.bundleIdentifier,
            localizedName: localizedName,
            processIdentifier: processIdentifier,
            phase: phase,
            updatedAt: .now,
        )
    }

    private func refreshObservedApplicationFromWorkspace() {
        guard let currentRunRequest else {
            observedApplication = nil
            return
        }

        if let runningApplication = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == currentRunRequest.bundleIdentifier
        }) {
            observedApplication = BriteLogObservedApplication(
                bundleIdentifier: currentRunRequest.bundleIdentifier,
                localizedName: runningApplication.localizedName,
                processIdentifier: runningApplication.processIdentifier,
                phase: .running,
                updatedAt: .now,
            )
        } else {
            observedApplication = BriteLogObservedApplication(
                bundleIdentifier: currentRunRequest.bundleIdentifier,
                localizedName: nil,
                processIdentifier: nil,
                phase: .waitingForLaunch,
                updatedAt: .now,
            )
        }
    }
}
