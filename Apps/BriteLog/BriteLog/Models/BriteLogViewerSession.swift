import BriteLogCore
import Foundation

struct BriteLogViewerSession: Equatable {
    enum State: String, Equatable {
        case idle
        case waitingForLaunch
        case attached
        case ended

        var displayName: String {
            switch self {
                case .idle:
                    "Idle"
                case .waitingForLaunch:
                    "Waiting For Launch"
                case .attached:
                    "Attached"
                case .ended:
                    "Ended"
            }
        }
    }

    var request: BriteLogRunRequest?
    var observedApplication: BriteLogObservedApplication?
    var records: [BriteLogRecord]
    var state: State
    var createdAt: Date
    var updatedAt: Date
    var endedAt: Date?

    static func idle(at date: Date) -> Self {
        Self(
            request: nil,
            observedApplication: nil,
            records: [],
            state: .idle,
            createdAt: date,
            updatedAt: date,
            endedAt: nil,
        )
    }
}
