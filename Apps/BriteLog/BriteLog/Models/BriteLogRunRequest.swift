import Foundation

struct BriteLogRunRequest: Codable, Equatable, Identifiable {
    enum Source: String, Codable, Equatable {
        case schemePreAction
    }

    var id: UUID
    var submittedAt: Date
    var projectPath: String
    var schemeName: String
    var targetName: String?
    var bundleIdentifier: String
    var buildConfiguration: String
    var builtProductPath: String?
    var source: Source

    init(
        id: UUID = UUID(),
        submittedAt: Date = .now,
        projectPath: String,
        schemeName: String,
        targetName: String? = nil,
        bundleIdentifier: String,
        buildConfiguration: String,
        builtProductPath: String? = nil,
        source: Source,
    ) {
        self.id = id
        self.submittedAt = submittedAt
        self.projectPath = projectPath
        self.schemeName = schemeName
        self.targetName = targetName
        self.bundleIdentifier = bundleIdentifier
        self.buildConfiguration = buildConfiguration
        self.builtProductPath = builtProductPath
        self.source = source
    }
}
