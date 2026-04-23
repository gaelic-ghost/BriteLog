import BriteLogCore
import BriteLogOSLogStore
import Foundation

struct BriteLogViewerSessionLiveRecordSource {
    var makeStream: @Sendable (BriteLogRunRequest) throws -> AsyncThrowingStream<BriteLogRecord, Error>

    static let live = Self { request in
        let source = BriteLogOSLogStoreSource(scope: .localStore)
        return try source.liveEntries(
            matching: BriteLogLiveRequest(
                start: .date(request.submittedAt),
                filter: BriteLogFilter(subsystem: request.bundleIdentifier),
                pollInterval: .milliseconds(250),
            ),
        )
    }
}
