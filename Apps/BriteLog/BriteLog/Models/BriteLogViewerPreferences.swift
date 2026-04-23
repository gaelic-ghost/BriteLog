import BriteLogCore
import Foundation

struct BriteLogViewerPreferences: Codable, Equatable {
    var searchText: String
    var highlightText: String
    var minimumLevel: BriteLogRecord.Level?
    var metadataMode: BriteLogMetadataMode

    static let `default` = Self(
        searchText: "",
        highlightText: "",
        minimumLevel: nil,
        metadataMode: .compact,
    )
}
