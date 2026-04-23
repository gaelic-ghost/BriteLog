import BriteLogCore
import Foundation
import Observation

@MainActor
@Observable
final class BriteLogAppModel {
    let storage: BriteLogAppStorage

    var configuration: BriteLogAppConfiguration
    var projectInstalls: [BriteLogProjectInstall]
    var lastErrorDescription: String?

    var applicationSupportPath: String {
        storage.applicationSupportDirectory.path
    }

    init(storage: BriteLogAppStorage = .init()) {
        self.storage = storage
        configuration = .default
        projectInstalls = []
        lastErrorDescription = nil
        reloadFromDisk()
    }

    func reloadFromDisk() {
        do {
            configuration = try storage.loadConfiguration()
            projectInstalls = try storage.loadProjectInstalls()
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
        integrationKind: BriteLogProjectInstall.IntegrationKind,
        notes: String? = nil,
    ) {
        let now = Date()

        if let existingIndex = projectInstalls.firstIndex(where: {
            $0.projectPath == projectPath && $0.schemeName == schemeName && $0.integrationKind == integrationKind
        }) {
            projectInstalls[existingIndex].displayName = displayName
            projectInstalls[existingIndex].notes = notes
            projectInstalls[existingIndex].updatedAt = now
        } else {
            projectInstalls.append(
                BriteLogProjectInstall(
                    displayName: displayName,
                    projectPath: projectPath,
                    schemeName: schemeName,
                    integrationKind: integrationKind,
                    notes: notes,
                    createdAt: now,
                    updatedAt: now,
                ),
            )
        }

        persistProjectInstalls()
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
}
