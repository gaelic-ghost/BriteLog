import AppKit
import BriteLogCore
import Foundation
import Observation

@MainActor
@Observable
final class BriteLogAppModel {
    struct WorkspaceApplicationSnapshot: Equatable {
        var bundleIdentifier: String?
        var localizedName: String?
        var processIdentifier: pid_t
    }

    let storage: BriteLogAppStorage
    var configuration: BriteLogAppConfiguration
    var projectInstalls: [BriteLogProjectInstall]
    var currentRunRequest: BriteLogRunRequest?
    var viewerSession: BriteLogViewerSession
    var lastErrorDescription: String?

    private let runningApplicationsProvider: @Sendable () -> [WorkspaceApplicationSnapshot]
    private let liveRecordSource: BriteLogViewerSessionLiveRecordSource
    private let currentDate: @Sendable () -> Date
    private let shouldStartSystemIntegration: Bool

    private var runRequestPollingTask: Task<Void, Never>?
    private var viewerRecordStreamingTask: Task<Void, Never>?
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var activeViewerRecordRequestID: UUID?

    var observedApplication: BriteLogObservedApplication? {
        viewerSession.observedApplication
    }

    var viewerPreferences: BriteLogViewerPreferences {
        configuration.viewerPreferences
    }

    var highlightRules: [BriteLogHighlightRule] {
        configuration.highlightRules
    }

    var applicationSupportPath: String {
        storage.applicationSupportDirectory.path
    }

    init(storage: BriteLogAppStorage = .init()) {
        self.storage = storage
        runningApplicationsProvider = Self.defaultRunningApplicationsProvider
        liveRecordSource = .live
        currentDate = Date.init
        shouldStartSystemIntegration = true
        let initialDate = Date()
        configuration = .default
        projectInstalls = []
        currentRunRequest = nil
        viewerSession = .idle(at: initialDate)
        lastErrorDescription = nil
        activeViewerRecordRequestID = nil
        reloadFromDisk()
        configureWorkspaceNotifications()
        startRunRequestPolling()
    }

    init(
        storage: BriteLogAppStorage,
        runningApplicationsProvider: @escaping @Sendable () -> [WorkspaceApplicationSnapshot],
        liveRecordSource: BriteLogViewerSessionLiveRecordSource = .live,
        currentDate: @escaping @Sendable () -> Date = Date.init,
        shouldStartSystemIntegration: Bool,
    ) {
        self.storage = storage
        self.runningApplicationsProvider = runningApplicationsProvider
        self.liveRecordSource = liveRecordSource
        self.currentDate = currentDate
        self.shouldStartSystemIntegration = shouldStartSystemIntegration
        let initialDate = currentDate()
        configuration = .default
        projectInstalls = []
        currentRunRequest = nil
        viewerSession = .idle(at: initialDate)
        lastErrorDescription = nil
        activeViewerRecordRequestID = nil
        reloadFromDisk()
        if shouldStartSystemIntegration {
            configureWorkspaceNotifications()
            startRunRequestPolling()
        }
    }

    private nonisolated static func defaultRunningApplicationsProvider() -> [WorkspaceApplicationSnapshot] {
        NSWorkspace.shared.runningApplications.map { application in
            WorkspaceApplicationSnapshot(
                bundleIdentifier: application.bundleIdentifier,
                localizedName: application.localizedName,
                processIdentifier: application.processIdentifier,
            )
        }
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

    func setViewerSearchText(_ value: String) {
        configuration.viewerPreferences.searchText = value
        persistConfiguration()
    }

    func setViewerHighlightText(_ value: String) {
        configuration.viewerPreferences.highlightText = value
        persistConfiguration()
    }

    func setViewerMinimumLevel(_ value: BriteLogRecord.Level?) {
        configuration.viewerPreferences.minimumLevel = value
        persistConfiguration()
    }

    func setViewerMetadataMode(_ value: BriteLogMetadataMode) {
        configuration.viewerPreferences.metadataMode = value
        persistConfiguration()
    }

    func addHighlightRule(
        name: String,
        matchText: String,
        subsystem: String,
        category: String,
        minimumLevel: BriteLogRecord.Level?,
    ) {
        let rule = BriteLogHighlightRule(
            name: name,
            matchText: matchText,
            subsystem: subsystem,
            category: category,
            minimumLevel: minimumLevel,
        )

        guard !rule.trimmedName.isEmpty else {
            lastErrorDescription = """
            BriteLog could not save a highlight rule because the rule name is empty.
            Give the rule a readable name so it can be managed later.
            """
            return
        }
        guard rule.hasConstraints else {
            lastErrorDescription = """
            BriteLog could not save highlight rule “\(rule.trimmedName)” because it has no match constraints.
            Add text, subsystem, category, or a minimum level before saving the rule.
            """
            return
        }

        configuration.highlightRules.append(rule)
        persistConfiguration()
    }

    func setHighlightRuleEnabled(
        ruleID: UUID,
        isEnabled: Bool,
    ) {
        guard let index = configuration.highlightRules.firstIndex(where: { $0.id == ruleID }) else {
            return
        }

        configuration.highlightRules[index].isEnabled = isEnabled
        persistConfiguration()
    }

    func removeHighlightRule(ruleID: UUID) {
        configuration.highlightRules.removeAll { $0.id == ruleID }
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

            applyRunRequest(request)
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    func applyRunRequest(_ request: BriteLogRunRequest) {
        currentRunRequest = request
        do {
            try storage.saveCurrentRunRequest(request)
            refreshObservedApplicationFromWorkspace()
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }

    func appendViewerRecords(_ records: [BriteLogRecord]) {
        guard !records.isEmpty else {
            return
        }
        guard let request = currentRunRequest else {
            return
        }

        let existingRecords = viewerSession.request?.id == request.id ? viewerSession.records : []
        let retainedRecords = Array((existingRecords + records).suffix(500))
        let updatedAt = records.last?.date ?? currentDate()

        viewerSession = makeViewerSession(
            request: request,
            observedApplication: viewerSession.observedApplication,
            state: viewerSession.state == .idle ? .waitingForLaunch : viewerSession.state,
            records: retainedRecords,
            preserveTimeline: true,
            updatedAt: updatedAt,
        )
    }

    func applyWorkspaceApplicationEvent(
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

        let observedApplication = BriteLogObservedApplication(
            bundleIdentifier: currentRunRequest.bundleIdentifier,
            localizedName: localizedName,
            processIdentifier: processIdentifier,
            phase: phase,
            updatedAt: currentDate(),
        )

        let sessionState: BriteLogViewerSession.State = switch phase {
            case .waitingForLaunch:
                .waitingForLaunch
            case .running:
                .attached
            case .terminated:
                .ended
        }

        viewerSession = makeViewerSession(
            request: currentRunRequest,
            observedApplication: observedApplication,
            state: sessionState,
            records: viewerSession.records,
            preserveTimeline: true,
        )
        syncViewerRecordStreaming()
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
        guard shouldStartSystemIntegration else {
            return
        }

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
        guard shouldStartSystemIntegration else {
            return
        }

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
                self?.applyWorkspaceApplicationEvent(
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
                self?.applyWorkspaceApplicationEvent(
                    bundleIdentifier: bundleIdentifier,
                    localizedName: localizedName,
                    processIdentifier: processIdentifier,
                    phase: .terminated,
                )
            }
        }
    }

    private func refreshObservedApplicationFromWorkspace() {
        guard let currentRunRequest else {
            viewerSession = .idle(at: currentDate())
            syncViewerRecordStreaming()
            return
        }

        if let runningApplication = runningApplicationsProvider().first(where: {
            $0.bundleIdentifier == currentRunRequest.bundleIdentifier
        }) {
            let observedApplication = BriteLogObservedApplication(
                bundleIdentifier: currentRunRequest.bundleIdentifier,
                localizedName: runningApplication.localizedName,
                processIdentifier: runningApplication.processIdentifier,
                phase: .running,
                updatedAt: currentDate(),
            )
            viewerSession = makeViewerSession(
                request: currentRunRequest,
                observedApplication: observedApplication,
                state: .attached,
                records: viewerSession.records,
                preserveTimeline: true,
            )
        } else {
            let observedApplication = BriteLogObservedApplication(
                bundleIdentifier: currentRunRequest.bundleIdentifier,
                localizedName: nil,
                processIdentifier: nil,
                phase: .waitingForLaunch,
                updatedAt: currentDate(),
            )
            viewerSession = makeViewerSession(
                request: currentRunRequest,
                observedApplication: observedApplication,
                state: .waitingForLaunch,
                records: viewerSession.records,
                preserveTimeline: true,
            )
        }

        syncViewerRecordStreaming()
    }

    private func makeViewerSession(
        request: BriteLogRunRequest?,
        observedApplication: BriteLogObservedApplication?,
        state: BriteLogViewerSession.State,
        records: [BriteLogRecord],
        preserveTimeline: Bool,
        updatedAt: Date? = nil,
    ) -> BriteLogViewerSession {
        let now = updatedAt ?? currentDate()
        guard let request else {
            return .idle(at: now)
        }

        let isSameRequest = preserveTimeline && viewerSession.request?.id == request.id
        let createdAt = isSameRequest ? viewerSession.createdAt : now
        let retainedRecords = isSameRequest ? records : []
        let endedAt = state == .ended ? now : nil

        return BriteLogViewerSession(
            request: request,
            observedApplication: observedApplication,
            records: retainedRecords,
            state: state,
            createdAt: createdAt,
            updatedAt: now,
            endedAt: endedAt,
        )
    }

    private func syncViewerRecordStreaming() {
        guard let request = viewerSession.request else {
            stopViewerRecordStreaming()
            return
        }
        guard viewerSession.state != .ended else {
            stopViewerRecordStreaming()
            return
        }
        guard activeViewerRecordRequestID != request.id else {
            return
        }

        stopViewerRecordStreaming()
        activeViewerRecordRequestID = request.id

        viewerRecordStreamingTask = Task { [weak self] in
            do {
                guard let strongSelf = self else {
                    return
                }

                let stream = try strongSelf.liveRecordSource.makeStream(request)

                for try await record in stream {
                    guard !Task.isCancelled else {
                        break
                    }

                    await MainActor.run {
                        guard let self else {
                            return
                        }
                        guard self.activeViewerRecordRequestID == request.id else {
                            return
                        }

                        self.appendViewerRecords([record])
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    guard self.activeViewerRecordRequestID == request.id else {
                        return
                    }

                    self.lastErrorDescription = """
                    BriteLog could not stream live records for bundle identifier \
                    \(request.bundleIdentifier). \(error.localizedDescription)
                    """
                }
            }
        }
    }

    private func stopViewerRecordStreaming() {
        viewerRecordStreamingTask?.cancel()
        viewerRecordStreamingTask = nil
        activeViewerRecordRequestID = nil
    }
}
