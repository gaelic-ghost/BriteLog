import BriteLogCore
import Foundation

struct BriteLogAppConfiguration: Codable, Equatable {
    var selectedTheme: BriteLogTheme
    var showViewerOnLaunch: Bool

    static let `default` = Self(
        selectedTheme: .xcode,
        showViewerOnLaunch: true,
    )
}
