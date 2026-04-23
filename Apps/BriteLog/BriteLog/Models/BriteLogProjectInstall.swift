import Foundation

struct BriteLogProjectInstall: Codable, Equatable, Identifiable {
    enum IntegrationKind: String, Codable, CaseIterable, Identifiable {
        case buildPlugin
        case schemeAction

        var id: Self { self }

        var displayName: String {
            switch self {
                case .buildPlugin:
                    "Build Plugin"
                case .schemeAction:
                    "Scheme Action"
            }
        }
    }

    var id: UUID
    var displayName: String
    var projectPath: String
    var schemeName: String?
    var integrationKind: IntegrationKind
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        projectPath: String,
        schemeName: String? = nil,
        integrationKind: IntegrationKind,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
    ) {
        self.id = id
        self.displayName = displayName
        self.projectPath = projectPath
        self.schemeName = schemeName
        self.integrationKind = integrationKind
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
