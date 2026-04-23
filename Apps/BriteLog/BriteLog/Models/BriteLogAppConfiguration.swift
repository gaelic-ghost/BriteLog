import BriteLogCore
import Foundation

struct BriteLogAppConfiguration: Codable, Equatable {
    var selectedTheme: BriteLogTheme
    var showViewerOnLaunch: Bool
    var viewerPreferences: BriteLogViewerPreferences
    var highlightRules: [BriteLogHighlightRule]

    static let `default` = Self(
        selectedTheme: .xcode,
        showViewerOnLaunch: true,
        viewerPreferences: .default,
        highlightRules: [],
    )
}
